//! AppleScript integration for interacting with macOS Reminders.app
//
// This module provides functions to interact with the Reminders application via AppleScript

use super::reminder_types::{ReminderConfig, ReminderError, ReminderItem};
use super::reminder_util::escape_applescript_string;
use anyhow::{Result, anyhow};
use log::{debug, error, info};
use std::process::Command;

/// Ensure Reminders.app is running
pub async fn ensure_reminders_running() -> Result<()> {
    let check_script = r#"tell application "Reminders"
        if it is not running then
            launch
            delay 1
        end if
        return "OK"
    end tell"#;

    let output = Command::new("osascript").arg("-e").arg(check_script).output()?;

    if output.status.success() { Ok(()) } else { Err(anyhow!(ReminderError::NotRunning)) }
}

/// Create a single reminder in Reminders.app
pub async fn create_single_reminder(config: ReminderConfig<'_>) -> Result<()> {
    debug!("Creating reminder with config: {:?}", config);

    // Make sure Reminders app is running
    ensure_reminders_running().await?;

    let target_lists = if config.lists.is_empty() { vec!["Reminders"] } else { config.lists };

    // Format reminder time to AppleScript-friendly string if provided
    let reminder_prop = if let Some(time_str) = config.reminder_time {
        // Parse input in format "YYYY-MM-DD HH:MM"
        match chrono::NaiveDateTime::parse_from_str(time_str, "%Y-%m-%d %H:%M") {
            Ok(naive_dt) => {
                // Format as "date \"MM/dd/yyyy hh:mm:ss AM/PM\""
                let formatted = naive_dt.format("%m/%d/%Y %I:%M:%S %p").to_string();
                debug!("Setting reminder time to: {}", formatted);
                // Use the correct AppleScript syntax for setting a due date on reminders
                format!(", due date:date \"{}\"", formatted)
            }
            Err(e) => {
                error!("Invalid reminder time format: {}", e);
                String::new()
            }
        }
    } else {
        String::new()
    };

    let mut success_count = 0;
    for list in target_lists {
        // Escape all inputs to prevent command injection
        let escaped_list = escape_applescript_string(list);
        let escaped_title = escape_applescript_string(config.title);
        let escaped_notes = escape_applescript_string(config.notes.as_deref().unwrap_or(""));

        // Updated AppleScript with escaped inputs
        let script = format!(
            r#"tell application "Reminders"
    try
        set remLists to lists whose name is "{}"
        if (count of remLists) > 0 then
            set targetList to item 1 of remLists
        else
            set targetList to make new list with properties {{name:"{}"}}
        end if
        
        set newReminder to make new reminder in targetList with properties {{name:"{}", body:"{}"{} }}
        
        return "Success: Reminder created"
    on error errMsg
        return "Error: " & errMsg
    end try
end tell"#,
            escaped_list, // search for list
            escaped_list, // create list if not found
            escaped_title,
            escaped_notes,
            reminder_prop
        );

        debug!("Executing AppleScript: {}", script);

        let output = Command::new("osascript").arg("-e").arg(&script).output()?;
        let result = String::from_utf8_lossy(&output.stdout);
        let error_output = String::from_utf8_lossy(&output.stderr);

        if !error_output.is_empty() {
            error!("AppleScript error: {}", error_output);
        }

        if result.contains("Success") {
            info!("Reminder created in list {}: {}", list, config.title);
            success_count += 1;
        } else {
            let error_msg = result.replace("Error: ", "");
            error!("Failed to create reminder in list {}: {}", list, error_msg);
        }
    }

    if success_count > 0 {
        Ok(())
    } else {
        Err(anyhow!(ReminderError::General(format!(
            "Failed to create reminder '{}' in any specified list",
            config.title
        ))))
    }
}

/// Get available reminder lists
pub async fn get_reminder_lists() -> Result<Vec<String>> {
    // Make sure Reminders app is running
    ensure_reminders_running().await?;

    let script = r#"tell application "Reminders"
    set listNames to {}
    repeat with l in lists
        copy (name of l) to the end of listNames
    end repeat
    return listNames
end tell"#;

    let output = Command::new("osascript").arg("-e").arg(script).output()?;
    if !output.status.success() {
        return Err(anyhow!(ReminderError::ScriptError(
            String::from_utf8_lossy(&output.stderr).to_string()
        )));
    }

    let lists_str = String::from_utf8_lossy(&output.stdout);
    let lists: Vec<String> = lists_str
        .trim_matches('{')
        .trim_matches('}')
        .split(", ")
        .map(|s| s.trim_matches('"').to_string())
        .collect();

    debug!("Found {} reminder lists", lists.len());
    Ok(lists)
}

/// Fetch reminders from a specific list or all lists
pub async fn fetch_reminders(list_name: Option<&str>) -> Result<Vec<ReminderItem>> {
    // Make sure Reminders app is running
    ensure_reminders_running().await?;

    let script = if let Some(list) = list_name {
        let escaped_list = escape_applescript_string(list);
        format!(
            r#"tell application "Reminders"
    set reminderList to {}
    set listObj to first list whose name is "{0}"
    repeat with r in (reminders in listObj)
        set reminderTitle to name of r
        set reminderCompleted to completed of r
        set reminderBody to ""
        try
            set reminderBody to body of r
        end try
        set reminderItem to {{title:reminderTitle, notes:reminderBody, completed:reminderCompleted, listName:"{0}"}}
        copy reminderItem to end of reminderList
    end repeat
    return reminderList
end tell"#,
            escaped_list
        )
    } else {
        r#"tell application "Reminders"
    set reminderList to {}
    repeat with l in lists
        set listName to name of l
        repeat with r in (reminders in l)
            set reminderTitle to name of r
            set reminderCompleted to completed of r
            set reminderBody to ""
            try
                set reminderBody to body of r
            end try
            set reminderItem to {title:reminderTitle, notes:reminderBody, completed:reminderCompleted, listName:listName}
            copy reminderItem to end of reminderList
        end repeat
    end repeat
    return reminderList
end tell"#
        .to_string()
    };

    let output = Command::new("osascript").arg("-e").arg(script).output()?;
    if !output.status.success() {
        return Err(anyhow!(ReminderError::ScriptError(
            String::from_utf8_lossy(&output.stderr).to_string()
        )));
    }

    // Parse the AppleScript output into ReminderItem structs
    let reminders_output = String::from_utf8_lossy(&output.stdout);
    let mut reminders = Vec::new();

    // Very basic parsing of AppleScript output - in a real implementation
    // you might want a more robust parser
    for line in reminders_output.lines() {
        if line.contains("title:") && line.contains("notes:") {
            // Extract data from line
            let mut title = String::new();
            let mut notes = None;
            let mut completed = false;
            let mut list_name = String::new();

            // Super simple parsing - you might want to improve this
            if let Some(title_start) = line.find("title:") {
                if let Some(title_end) = line[title_start..].find(",") {
                    title = line[title_start + 6..title_start + title_end].trim().to_string();
                }
            }

            if let Some(notes_start) = line.find("notes:") {
                if let Some(notes_end) = line[notes_start..].find(",") {
                    let note_text =
                        line[notes_start + 6..notes_start + notes_end].trim().to_string();
                    if !note_text.is_empty() {
                        notes = Some(note_text);
                    }
                }
            }

            if let Some(completed_start) = line.find("completed:") {
                if let Some(completed_str) = line[completed_start + 10..].split_whitespace().next()
                {
                    completed = completed_str == "true";
                }
            }

            if let Some(list_start) = line.find("listName:") {
                list_name = line[list_start + 9..].trim().to_string();
            }

            reminders.push(ReminderItem {
                title,
                notes,
                lists: vec![list_name],
                reminder_time: None, // We don't parse this in this example
                completed,
            });
        }
    }

    debug!("Fetched {} reminders", reminders.len());
    Ok(reminders)
}

/// Delete a reminder by title and list
pub async fn delete_reminder(title: &str, list_name: Option<&str>) -> Result<()> {
    // Make sure Reminders app is running
    ensure_reminders_running().await?;

    let escaped_title = escape_applescript_string(title);

    let script = if let Some(list) = list_name {
        let escaped_list = escape_applescript_string(list);
        format!(
            r#"tell application "Reminders"
    try
        set targetList to first list whose name is "{}"
        set itemsToDelete to (reminders in targetList whose name is "{}")
        if (count of itemsToDelete) > 0 then
            delete itemsToDelete
            return "Success: Reminder deleted"
        else
            return "Error: Reminder not found in specified list"
        end if
    on error errMsg
        return "Error: " & errMsg
    end try
end tell"#,
            escaped_list, escaped_title
        )
    } else {
        format!(
            r#"tell application "Reminders"
    try
        set foundReminder to false
        repeat with l in lists
            set itemsToDelete to (reminders in l whose name is "{}")
            if (count of itemsToDelete) > 0 then
                delete itemsToDelete
                set foundReminder to true
            end if
        end repeat
        
        if foundReminder then
            return "Success: Reminder deleted"
        else
            return "Error: Reminder not found in any list"
        end if
    on error errMsg
        return "Error: " & errMsg
    end try
end tell"#,
            escaped_title
        )
    };

    let output = Command::new("osascript").arg("-e").arg(&script).output()?;
    let result = String::from_utf8_lossy(&output.stdout);

    if result.contains("Success") {
        info!("Reminder deleted: {}", title);
        Ok(())
    } else {
        let error_msg = result.replace("Error: ", "");
        error!("Failed to delete reminder: {}", error_msg);

        if error_msg.contains("not found") {
            Err(anyhow!(ReminderError::ReminderNotFound(title.to_string())))
        } else {
            Err(anyhow!(ReminderError::ScriptError(error_msg)))
        }
    }
}
