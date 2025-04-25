use anyhow::{Result, anyhow};
use log::{debug, info, warn};
use std::collections::HashMap;
use std::fmt::Debug;
use std::future::Future;
use std::pin::Pin;

/// Command line arguments structure
#[derive(Debug, Clone)]
pub struct CommandArgs {
    pub command: String,
    pub args: Vec<String>,
    pub flags: HashMap<String, Option<String>>,
}

impl CommandArgs {
    /// Create a new CommandArgs instance directly
    pub fn new(command: String, args: Vec<String>, flags: HashMap<String, Option<String>>) -> Self {
        Self { command, args, flags }
    }

    /// Legacy method for parsing command arguments from a string
    /// This is deprecated in favor of using the Clap-based command line parser
    #[deprecated(note = "Use the Clap-based command line parser instead")]
    pub fn parse(input: &str) -> Result<Self> {
        // Normalize input by replacing non-breaking spaces with regular spaces
        let normalized_input = input.replace('\u{a0}', " ");
        debug!("Normalized input: {}", normalized_input);

        // Tokenize the input, correctly handling quoted strings
        let tokens = tokenize_input(&normalized_input)?;
        debug!("Tokenized input: {:?}", tokens);

        if tokens.is_empty() {
            return Err(anyhow!("No command provided"));
        }

        // Extract command, removing 'ducktape' if present
        let mut tokens_iter = tokens.into_iter();
        let first_token = tokens_iter.next().unwrap();

        // Command is either the first token or the second if first is "ducktape"
        let command = if first_token.eq_ignore_ascii_case("ducktape") {
            tokens_iter
                .next()
                .ok_or_else(|| anyhow!("No command provided after 'ducktape'"))?
                .to_lowercase()
        } else {
            first_token.to_lowercase()
        };

        // Process remaining tokens into args and flags
        let mut args = Vec::new();
        let mut flags = HashMap::new();

        let mut current_flag: Option<String> = None;

        for token in tokens_iter {
            if token.starts_with("--") {
                // This is a new flag
                if let Some(flag_name) = current_flag.take() {
                    // Previous flag had no value
                    flags.insert(flag_name, None);
                }

                // Store new flag name (without prefix)
                current_flag = Some(token[2..].to_string());
                debug!("Found flag: --{}", current_flag.as_ref().unwrap());
            } else if let Some(flag_name) = current_flag.take() {
                // This token is the value for the current flag
                debug!("Flag --{} has value: '{}'", flag_name, token);
                flags.insert(flag_name, Some(token));
            } else {
                // Regular argument
                args.push(token);
            }
        }

        // Handle any remaining flag with no value
        if let Some(flag_name) = current_flag {
            flags.insert(flag_name, None);
        }

        // Process special cases like calendar create with multi-word titles
        if command == "calendar" && !args.is_empty() && args[0] == "create" {
            process_calendar_create_args(&mut args);
        }

        debug!("Final parsed command: {:?}, args: {:?}, flags: {:?}", command, args, flags);

        Ok(CommandArgs { command, args, flags })
    }

    // Keep for backward compatibility, but mark as deprecated
    #[deprecated(note = "This method is no longer used")]
    #[allow(dead_code)]
    fn process_special_flag(_args: &[String], i: usize) -> (usize, String, Option<String>) {
        // Just a stub to maintain backward compatibility
        let flag_name = _args[i][2..].to_string();
        (i + 1, flag_name, None)
    }
}

/// Tokenizes the input command line, properly handling both escaped and regular quotes
/// Tokenizes the input command line, properly handling both escaped and regular quotes
fn tokenize_input(input: &str) -> Result<Vec<String>> {
    debug!("Starting tokenization of input: '{}'", input);

    // Use shell_words for robust shell-like parsing
    match shell_words::split(input) {
        Ok(tokens) => {
            // Post-process the tokens to handle special flags like --contacts
            let processed_tokens = postprocess_flags(&tokens);
            debug!("Tokenization result after post-processing: {:?}", processed_tokens);
            Ok(processed_tokens)
        }
        Err(e) => {
            debug!("shell_words parsing failed: {}, falling back to manual parsing", e);
            // Fall back to our manual parser
            let mut tokens = Vec::new();
            let mut current_token = String::new();

            // State variables
            let mut in_quotes = false;
            let mut escaped = false;

            for c in input.chars() {
                if escaped {
                    current_token.push(c);
                    escaped = false;
                } else if c == '\\' {
                    escaped = true;
                } else if c == '"' {
                    in_quotes = !in_quotes;
                } else if c.is_whitespace() && !in_quotes {
                    if !current_token.is_empty() {
                        tokens.push(current_token);
                        current_token = String::new();
                    }
                } else {
                    current_token.push(c);
                }
            }

            if !current_token.is_empty() {
                tokens.push(current_token);
            }

            if in_quotes {
                return Err(anyhow!("Unclosed quote in input"));
            }

            // Post-process the manually parsed tokens as well
            let processed_tokens = postprocess_flags(&tokens);
            debug!("Manual tokenization result after post-processing: {:?}", processed_tokens);
            Ok(processed_tokens)
        }
    }
}

/// Post-processes flags to handle special cases
fn postprocess_flags(tokens: &[String]) -> Vec<String> {
    let mut result = Vec::new();
    let mut i = 0;

    while i < tokens.len() {
        // Get the current token
        let token = &tokens[i];

        // Special handling for --contacts flag
        if token == "--contacts" && i + 1 < tokens.len() {
            debug!("Found --contacts flag, checking for multi-word/multi-contact value");
            result.push(token.clone());

            // Get the next token for reference
            let next_token = &tokens[i + 1];

            // Check if the value is already quoted properly - we'll keep it as is
            // as it might contain comma-separated values that should be preserved
            if (next_token.starts_with('"') && next_token.ends_with('"'))
                || (next_token.starts_with('\'') && next_token.ends_with('\''))
            {
                debug!("Using quoted contacts list: '{}'", next_token);
                result.push(next_token.clone());
                i += 2; // Skip flag and quoted value
                continue;
            }

            // Need to collect all tokens that might be part of the contact string
            // (until we hit another flag or end of input)
            let mut contact_parts = Vec::new();
            let mut j = i + 1;

            while j < tokens.len() && !tokens[j].starts_with("--") {
                contact_parts.push(tokens[j].clone());
                j += 1;
            }

            // If we have multiple parts, combine them
            if !contact_parts.is_empty() {
                let contact_str = contact_parts.join(" ");
                debug!("Combined contact string: '{}'", contact_str);

                // Add quotes around the combined contact string if it's not already quoted
                if (contact_str.starts_with('"') && contact_str.ends_with('"'))
                    || (contact_str.starts_with('\'') && contact_str.ends_with('\''))
                {
                    result.push(contact_str);
                } else {
                    result.push(format!("\"{}\"", contact_str));
                }

                i = j; // Skip to the position after all contact parts
            } else {
                // No contact parts found (shouldn't normally happen)
                i += 2;
            }
        }
        // Special handling for other flags that might need quoted values
        else if token.starts_with("--")
            && ["location", "notes", "email", "contacts"].contains(&&token[2..])
            && i + 1 < tokens.len()
        {
            debug!("Found special flag: {}", token);
            result.push(token.clone());

            // Add the value as-is, preserving quotes if present
            let value = &tokens[i + 1];
            result.push(value.clone());
            i += 2; // Skip the flag and value
        } else {
            // No special handling needed
            result.push(token.clone());
            i += 1;
        }
    }

    result
}
/// Process calendar create command arguments to handle multi-word titles
fn process_calendar_create_args(args: &mut Vec<String>) {
    if args.len() < 2 {
        return;
    }

    // Only process if the first argument doesn't already contain spaces
    // (which would indicate it was properly quoted)
    if !args[1].contains(' ') {
        let mut i = 1;
        let mut title_parts = vec![args[i].clone()];
        i += 1;

        // Collect words until we find a date/time-like format
        while i < args.len() {
            if args[i].contains('-') || args[i].contains(':') {
                break;
            }
            title_parts.push(args[i].clone());
            i += 1;
        }

        if title_parts.len() > 1 {
            let combined_title = title_parts.join(" ");
            debug!("Combined multi-word title: '{}'", combined_title);

            // Create new args vector
            let mut new_args = vec![args[0].clone()];
            new_args.push(combined_title);
            new_args.extend_from_slice(&args[title_parts.len() + 1..]);
            *args = new_args;
        }
    }
}

// Command handler trait for handling commands
pub trait CommandHandler: Debug + Send + Sync {
    fn execute(&self, args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>>;
    fn can_handle(&self, command: &str) -> bool;
}

// Calendar handler
#[derive(Debug)]
pub struct CalendarHandler;

impl CommandHandler for CalendarHandler {
    fn execute(&self, args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            match args.args.first().map(|s| s.as_str()) {
                Some("create") => {
                    if args.args.len() < 5 {
                        println!("Not enough arguments for calendar create command");
                        println!(
                            "Usage: ducktape calendar create <title> <date> <start_time> <end_time> [calendar]"
                        );
                        return Ok(());
                    }

                    // Special handling for multi-word titles in calendar create command
                    let mut combined_title = String::new();
                    let mut _title_index = 1;
                    let mut date_index = 2;
                    if args.args.len() >= 6
                        && !args.args[1].contains('-')
                        && !args.args[1].contains(':')
                        && !args.args[2].contains('-')
                        && !args.args[2].contains(':')
                        && (args.args[3].contains('-') || args.args[3].contains('/'))
                    {
                        debug!("Detected potential multi-word title");
                        combined_title = format!("{} {}", args.args[1], args.args[2]);
                        _title_index = 0;
                        date_index = 3;
                    }
                    let raw_title = if !combined_title.is_empty() {
                        combined_title
                    } else {
                        args.args[1].clone()
                    };
                    let title = raw_title.trim_matches('"');
                    let mut date = args.args[date_index].clone();
                    let start_time = &args.args[date_index + 1];
                    let end_time = &args.args[date_index + 2];

                    // --- NEW: resolve relative date strings ---
                    if date.eq_ignore_ascii_case("today") || date.eq_ignore_ascii_case("tomorrow") {
                        match crate::reminder::resolve_relative_date(&date) {
                            Ok(resolved) => {
                                debug!("Resolved relative date '{}' to '{}'.", date, resolved);
                                date = resolved;
                            }
                            Err(e) => {
                                log::warn!("Could not resolve relative date '{}': {}", date, e);
                                println!("Invalid date: {}", date);
                                return Ok(());
                            }
                        }
                    }
                    // --- END NEW ---

                    // Check if the date_index + 3 argument is a calendar or part of a flag
                    let calendar = if args
                        .args
                        .get(date_index + 3)
                        .map_or(false, |arg| !arg.starts_with("--"))
                    {
                        args.args
                            .get(date_index + 3)
                            .cloned()
                            .map(|cal| cal.trim_matches('"').to_string())
                    } else {
                        debug!("No explicit calendar specified, will use default calendar");
                        None
                    };

                    log::info!(
                        "Processing calendar event with title: '{}', date: {}, times: {} to {}",
                        title,
                        date,
                        start_time,
                        end_time
                    );

                    // Build flags and trim surrounding quotes if present
                    let location = args
                        .flags
                        .get("location")
                        .cloned()
                        .flatten()
                        .map(|loc| loc.trim_matches('"').to_string());
                    let description = args
                        .flags
                        .get("notes")
                        .cloned()
                        .flatten()
                        .map(|desc| desc.trim_matches('"').to_string());
                    let emails = args
                        .flags
                        .get("email")
                        .cloned()
                        .flatten()
                        .map(|email| email.trim_matches('"').to_string());

                    let contacts = args.flags.get("contacts").cloned().flatten().map(|contact| {
                        // Properly trim surrounding quotes and maintain multi-word names
                        let trimmed = contact.trim_matches('"').trim_matches('\'').to_string();
                        debug!("Contacts flag value after trimming quotes: '{}'", trimmed);
                        trimmed
                    });

                    debug!("Contacts flag value: {:?}", contacts);

                    // Handle recurrence options
                    let recurrence_frequency =
                        args.flags.get("repeat").or(args.flags.get("recurring")).cloned().flatten();
                    let interval = args.flags.get("interval").cloned().flatten();
                    let until_date = args.flags.get("until").cloned().flatten();
                    let count = args.flags.get("count").cloned().flatten();
                    let days = args.flags.get("days").cloned().flatten();

                    // Create event config and pass to calendar module
                    let mut config = crate::calendar::EventConfig::new(title, &date, start_time);
                    config.end_time = Some(end_time.clone());

                    // Validate calendar name
                    let available_calendars = crate::calendar::get_available_calendars().await?;
                    if let Some(cal) = &calendar {
                        if !available_calendars.contains(cal) {
                            warn!(
                                "Specified calendar '{}' not found. Falling back to default calendar.",
                                cal
                            );
                            println!(
                                "Warning: Calendar '{}' not found. Using default calendar.",
                                cal
                            );
                            config.calendars = vec!["Work".to_string()]; // Fallback to default calendar
                        } else {
                            config.calendars = vec![cal.clone()];
                        }
                    } else {
                        config.calendars = vec!["Work".to_string()]; // Use default calendar if none specified
                    }

                    config.location = location;
                    config.description = description;

                    // Check for --zoom flag and set create_zoom_meeting property
                    if args.flags.contains_key("zoom") {
                        info!("Zoom flag detected, creating event with Zoom meeting");
                        config.create_zoom_meeting = true;
                    }

                    // Process recurrence information if provided
                    if let Some(freq_str) = recurrence_frequency {
                        match crate::calendar::RecurrenceFrequency::from_str(&freq_str) {
                            Ok(frequency) => {
                                info!("Creating recurring event with frequency: {}", freq_str);
                                let mut recurrence =
                                    crate::calendar::RecurrencePattern::new(frequency);

                                // Add interval if specified
                                if let Some(interval_str) = interval {
                                    if let Ok(interval_val) = interval_str.parse::<u32>() {
                                        recurrence = recurrence.with_interval(interval_val);
                                        debug!("Setting recurrence interval: {}", interval_val);
                                    }
                                }

                                // Add end date if specified
                                if let Some(until) = until_date {
                                    recurrence = recurrence.with_end_date(&until);
                                    debug!("Setting recurrence end date: {}", until);
                                }

                                // Add count if specified
                                if let Some(count_str) = count {
                                    if let Ok(count_val) = count_str.parse::<u32>() {
                                        recurrence = recurrence.with_count(count_val);
                                        debug!("Setting recurrence count: {}", count_val);
                                    }
                                }

                                // Add days if specified
                                if let Some(days_str) = days {
                                    let day_values: Vec<u8> = days_str
                                        .split(',')
                                        .filter_map(|s| s.trim().parse::<u8>().ok())
                                        .collect();
                                    if !day_values.is_empty() {
                                        recurrence = recurrence.with_days_of_week(&day_values);
                                        debug!("Setting recurrence days: {:?}", day_values);
                                    }
                                }

                                config.recurrence = Some(recurrence);
                            }
                            Err(e) => {
                                warn!("Invalid recurrence frequency '{}': {}", freq_str, e);
                            }
                        }
                    }

                    // Process emails if provided
                    if let Some(email_str) = emails {
                        config.emails = email_str
                            .split(',')
                            .map(|s| s.trim().to_string())
                            .filter(|email| crate::calendar::validate_email(email))
                            .collect();
                        debug!("Added {} email attendees", config.emails.len());
                    }

                    // If contacts are specified, use create_event_with_contacts
                    if let Some(contacts_str) = contacts {
                        info!("Processing contacts string: '{}'", contacts_str);

                        // Process contact string and convert to a vector of string slices
                        // First split by commas to handle multiple contacts
                        let contact_vec: Vec<&str> = contacts_str
                            .split(',')
                            .map(|s| s.trim())
                            .filter(|s| !s.is_empty())
                            .collect();

                        if !contact_vec.is_empty() {
                            info!(
                                "Creating event with {} contact(s): {:?}",
                                contact_vec.len(),
                                contact_vec
                            );
                            return crate::calendar::create_event_with_contacts(
                                config,
                                &contact_vec,
                            )
                            .await;
                        }
                    }

                    crate::calendar::create_event(config).await
                }
                Some("list") => crate::calendar::list_calendars().await,
                Some("props") | None if args.command == "calendar-props" => {
                    crate::calendar::list_event_properties().await
                }
                Some("show") => {
                    // TODO: Implement show calendar functionality
                    println!("Show calendar functionality is not implemented yet.");
                    Ok(())
                }
                _ => {
                    println!(
                        "Unknown calendar command. Available commands: create, list, show, props"
                    );
                    Ok(())
                }
            }
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "calendar" || command == "calendars" || command == "calendar-props"
    }
}

// Todo handler
#[derive(Debug)]
pub struct TodoHandler;

impl CommandHandler for TodoHandler {
    fn execute(&self, args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            match args.args.first().map(|s| s.as_str()) {
                Some("create") | Some("add") => {
                    if args.args.len() < 2 {
                        println!("Not enough arguments for todo create command");
                        println!("Usage: ducktape todo create <title> [list1] [list2] ...");
                        return Ok(());
                    }

                    let title = &args.args[1];

                    // Create a new TodoConfig with the title
                    let mut config = crate::todo::TodoConfig::new(title);

                    // Set lists if provided in arguments (args[2] and beyond are list names)
                    if args.args.len() > 2 {
                        // Only collect lists that don't start with "--" (those are flags)
                        let list_names: Vec<&str> = args.args[2..]
                            .iter()
                            .map(|s| s.as_str())
                            .filter(|s| !s.starts_with("--"))
                            .collect();

                        if !list_names.is_empty() {
                            config.lists = list_names;
                        }
                    }

                    // Process standard flags (like --remind)
                    // Look for --remind flag in both formats: as key in flags HashMap or as commandline arg
                    let reminder_time = if let Some(Some(time)) = args.flags.get("remind") {
                        // Found in the flags HashMap
                        debug!("Found reminder time in flags HashMap: {}", time);
                        Some(time.as_str())
                    } else if let Some(remind_idx) =
                        args.args.iter().position(|arg| arg == "--remind")
                    {
                        // Found as a commandline arg
                        if remind_idx + 1 < args.args.len() {
                            let time = &args.args[remind_idx + 1];
                            debug!("Found reminder time as arg: {}", time);
                            Some(time.trim_matches('"').trim_matches('\''))
                        } else {
                            None
                        }
                    } else {
                        None
                    };

                    if let Some(time_str) = reminder_time {
                        debug!("Setting reminder time: {}", time_str);
                        config.reminder_time = Some(time_str);
                    }

                    // Set notes if provided via --notes flag (similar approach as reminder time)
                    let notes = if let Some(Some(note_text)) = args.flags.get("notes") {
                        // Found in the flags HashMap
                        Some(note_text.clone())
                    } else if let Some(notes_idx) =
                        args.args.iter().position(|arg| arg == "--notes")
                    {
                        // Found as a commandline arg
                        if notes_idx + 1 < args.args.len() {
                            Some(args.args[notes_idx + 1].clone())
                        } else {
                            None
                        }
                    } else {
                        None
                    };

                    if let Some(note_text) = notes {
                        debug!("Setting notes: {}", note_text);
                        config.notes =
                            Some(note_text.trim_matches('"').trim_matches('\'').to_string());
                    }

                    debug!("Final todo config: {:?}", config);

                    // Use await with the async create_todo function
                    match crate::todo::create_todo(config).await {
                        Ok(_) => {
                            println!("Todo '{}' created successfully", title);
                            Ok(())
                        }
                        Err(e) => {
                            println!("Failed to create todo: {}", e);
                            Err(anyhow!("Failed to create todo: {}", e))
                        }
                    }
                }
                Some("list") => {
                    // Implementation for listing todos would go here using async/await
                    println!("Listing todos... (not implemented yet)");
                    Ok(())
                }
                Some("delete") => {
                    // Implementation for deleting todos would go here using async/await
                    println!("Deleting todo... (not implemented yet)");
                    Ok(())
                }
                _ => {
                    println!("Unknown todo command. Available commands: create/add, list, delete");
                    Ok(())
                }
            }
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "todo" || command == "todos"
    }
}

// Notes handler
#[derive(Debug)]
pub struct NotesHandler;

impl CommandHandler for NotesHandler {
    fn execute(&self, args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            match args.args.first().map(|s| s.as_str()) {
                Some("create") | Some("add") => {
                    if args.args.len() < 2 {
                        println!("Not enough arguments for note create command");
                        println!(
                            "Usage: ducktape note create <title> [content] [--folder <folder_name>]"
                        );
                        return Ok(());
                    }

                    // Combine all non-flag arguments after "create" into a single title if not quoted
                    // This handles cases like "ducktape note create Project ideas for Q2"
                    let mut title_parts = Vec::new();
                    let mut i = 1;
                    while i < args.args.len() && !args.args[i].starts_with("--") {
                        title_parts.push(args.args[i].trim_matches('"'));
                        i += 1;
                    }

                    // If we have multiple parts and the first doesn't contain spaces (which would indicate quotes were used)
                    let title = if title_parts.len() > 1 && !args.args[1].contains(' ') {
                        title_parts.join(" ")
                    } else {
                        args.args[1].trim_matches('"').to_string()
                    };

                    // Get content from --content flag or as the next positional argument after title
                    let content = if let Some(Some(content_val)) = args.flags.get("content") {
                        content_val.trim_matches('"')
                    } else if args.args.len() > 2 && !args.args[2].starts_with("--") {
                        args.args[2].trim_matches('"')
                    } else {
                        ""
                    };

                    // Get folder from --folder flag
                    let folder = args.flags.get("folder").and_then(|f| f.as_deref());

                    debug!(
                        "Creating note: title='{}', content_length={}, folder={:?}",
                        title,
                        content.len(),
                        folder
                    );

                    // Create note config using the new structure
                    let config = crate::notes::NoteConfig { title: &title, content, folder };

                    match crate::notes::create_note(config).await {
                        Ok(_) => {
                            println!("Note created successfully: {}", title);
                            Ok(())
                        }
                        Err(e) => {
                            println!("Failed to create note: {}", e);
                            Err(anyhow!("Failed to create note: {}", e))
                        }
                    }
                }
                Some("list") => match crate::notes::list_notes().await {
                    Ok(notes) => {
                        if notes.is_empty() {
                            println!("No notes found");
                        } else {
                            println!("Notes:");
                            for note in notes {
                                println!("  - {} (in folder: {})", note.title, note.folder);
                            }
                        }
                        Ok(())
                    }
                    Err(e) => {
                        println!("Failed to list notes: {}", e);
                        Err(e)
                    }
                },
                Some("folders") => match crate::notes::get_note_folders().await {
                    Ok(folders) => {
                        if folders.is_empty() {
                            println!("No note folders found");
                        } else {
                            println!("Note folders:");
                            for folder in folders {
                                println!("  - {}", folder);
                            }
                        }
                        Ok(())
                    }
                    Err(e) => {
                        println!("Failed to get note folders: {}", e);
                        Err(e)
                    }
                },
                Some("delete") => {
                    if args.args.len() < 2 {
                        println!("Not enough arguments for note delete command");
                        println!("Usage: ducktape note delete <title> [--folder <folder_name>]");
                        return Ok(());
                    }

                    // Handle multi-word titles for delete command too
                    let mut title_parts = Vec::new();
                    let mut i = 1;
                    while i < args.args.len() && !args.args[i].starts_with("--") {
                        title_parts.push(args.args[i].trim_matches('"'));
                        i += 1;
                    }

                    // If we have multiple parts and the first doesn't contain spaces (which would indicate quotes were used)
                    let title = if title_parts.len() > 1 && !args.args[1].contains(' ') {
                        title_parts.join(" ")
                    } else {
                        args.args[1].trim_matches('"').to_string()
                    };

                    let folder = args.flags.get("folder").and_then(|f| f.as_deref());

                    match crate::notes::delete_note(&title, folder).await {
                        Ok(_) => {
                            println!("Note deleted successfully: {}", title);
                            Ok(())
                        }
                        Err(e) => {
                            println!("Failed to delete note: {}", e);
                            Err(e)
                        }
                    }
                }
                Some("search") => {
                    if args.args.len() < 2 {
                        println!("Not enough arguments for note search command");
                        println!("Usage: ducktape note search <keyword>");
                        return Ok(());
                    }

                    // Handle multi-word keywords for search command too
                    let mut keyword_parts = Vec::new();
                    let mut i = 1;
                    while i < args.args.len() && !args.args[i].starts_with("--") {
                        keyword_parts.push(args.args[i].trim_matches('"'));
                        i += 1;
                    }

                    // If we have multiple parts and the first doesn't contain spaces (which would indicate quotes were used)
                    let keyword = if keyword_parts.len() > 1 && !args.args[1].contains(' ') {
                        keyword_parts.join(" ")
                    } else {
                        args.args[1].trim_matches('"').to_string()
                    };

                    match crate::notes::search_notes(&keyword).await {
                        Ok(notes) => {
                            if notes.is_empty() {
                                println!("No notes found matching '{}'", keyword);
                            } else {
                                println!("Notes matching '{}':", keyword);
                                for note in notes {
                                    println!("  - {} (in folder: {})", note.title, note.folder);
                                }
                            }
                            Ok(())
                        }
                        Err(e) => {
                            println!("Failed to search notes: {}", e);
                            Err(e)
                        }
                    }
                }
                _ => {
                    println!(
                        "Unknown notes command. Available commands: create/add, list, folders, delete, search"
                    );
                    Ok(())
                }
            }
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "note" || command == "notes"
    }
}

// Config handler
#[derive(Debug)]
pub struct ConfigHandler;

impl CommandHandler for ConfigHandler {
    fn execute(&self, args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            match args.args.first().map(|s| s.as_str()) {
                Some("set") => {
                    if args.args.len() < 3 {
                        println!("Not enough arguments for config set command");
                        println!("Usage: ducktape config set <key> <value>");
                        return Ok(());
                    }

                    let key = &args.args[1];
                    let value = &args.args[2];

                    // Load config
                    let mut config = crate::config::Config::load()?;

                    // Update config based on key
                    match key.as_str() {
                        "calendar.default" => {
                            config.calendar.default_calendar = Some(value.clone());
                        }
                        "calendar.reminder" => {
                            if let Ok(minutes) = value.parse::<i32>() {
                                config.calendar.default_reminder_minutes = Some(minutes);
                            } else {
                                println!("Invalid reminder minutes value: {}", value);
                                return Ok(());
                            }
                        }
                        "calendar.duration" => {
                            if let Ok(minutes) = value.parse::<i32>() {
                                config.calendar.default_duration_minutes = Some(minutes);
                            } else {
                                println!("Invalid duration minutes value: {}", value);
                                return Ok(());
                            }
                        }
                        "todo.default_list" => {
                            config.todo.default_list = Some(value.clone());
                        }
                        "notes.default_folder" => {
                            config.notes.default_folder = Some(value.clone());
                        }
                        "language_model.provider" => match value.to_lowercase().as_str() {
                            "grok" => {
                                config.language_model.provider =
                                    Some(crate::config::LLMProvider::Grok);
                            }
                            "deepseek" => {
                                config.language_model.provider =
                                    Some(crate::config::LLMProvider::DeepSeek);
                            }
                            _ => {
                                println!("Invalid language model provider: {}", value);
                                println!("Valid options are: grok, deepseek");
                                return Ok(());
                            }
                        },
                        _ => {
                            println!("Unknown config key: {}", key);
                            return Ok(());
                        }
                    }

                    // Save updated config
                    config.save()?;
                    println!("Config updated: {} = {}", key, value);
                    Ok(())
                }
                Some("get") | Some("show") => {
                    if args.args.len() < 2 {
                        println!("Not enough arguments for config get/show command");
                        println!("Usage: ducktape config get <key> or ducktape config show <key>");
                        return Ok(());
                    }

                    let key = &args.args[1];
                    let config = crate::config::Config::load()?;

                    // Get config value based on key
                    match key.as_str() {
                        "calendar.default" => {
                            println!(
                                "calendar.default = {}",
                                config
                                    .calendar
                                    .default_calendar
                                    .unwrap_or_else(|| "Not set".to_string())
                            );
                        }
                        "calendar.reminder" => {
                            println!(
                                "calendar.reminder = {}",
                                config
                                    .calendar
                                    .default_reminder_minutes
                                    .map_or_else(|| "Not set".to_string(), |m| m.to_string())
                            );
                        }
                        "calendar.duration" => {
                            println!(
                                "calendar.duration = {}",
                                config
                                    .calendar
                                    .default_duration_minutes
                                    .map_or_else(|| "Not set".to_string(), |m| m.to_string())
                            );
                        }
                        "todo.default_list" => {
                            println!(
                                "todo.default_list = {}",
                                config.todo.default_list.unwrap_or_else(|| "Not set".to_string())
                            );
                        }
                        "notes.default_folder" => {
                            println!(
                                "notes.default_folder = {}",
                                config
                                    .notes
                                    .default_folder
                                    .unwrap_or_else(|| "Not set".to_string())
                            );
                        }
                        "language_model.provider" => {
                            let provider = match config.language_model.provider {
                                Some(crate::config::LLMProvider::Grok) => "grok",
                                Some(crate::config::LLMProvider::DeepSeek) => "deepseek",
                                None => "none",
                            };
                            println!("language_model.provider = {}", provider);
                        }
                        "all" => {
                            println!("Current Configuration:");
                            println!("======================");
                            println!(
                                "calendar.default = {}",
                                config
                                    .calendar
                                    .default_calendar
                                    .unwrap_or_else(|| "Not set".to_string())
                            );
                            println!(
                                "calendar.reminder = {}",
                                config
                                    .calendar
                                    .default_reminder_minutes
                                    .map_or_else(|| "Not set".to_string(), |m| m.to_string())
                            );
                            println!(
                                "calendar.duration = {}",
                                config
                                    .calendar
                                    .default_duration_minutes
                                    .map_or_else(|| "Not set".to_string(), |m| m.to_string())
                            );
                            println!(
                                "todo.default_list = {}",
                                config.todo.default_list.unwrap_or_else(|| "Not set".to_string())
                            );
                            println!(
                                "notes.default_folder = {}",
                                config
                                    .notes
                                    .default_folder
                                    .unwrap_or_else(|| "Not set".to_string())
                            );
                            let provider = match config.language_model.provider {
                                Some(crate::config::LLMProvider::Grok) => "grok",
                                Some(crate::config::LLMProvider::DeepSeek) => "deepseek",
                                None => "none",
                            };
                            println!("language_model.provider = {}", provider);
                        }
                        _ => {
                            println!("Unknown config key: {}", key);
                        }
                    }
                    Ok(())
                }
                _ => {
                    println!("Unknown config command. Available commands: set, get, show");
                    Ok(())
                }
            }
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "config"
    }
}

// Utilities handler
#[derive(Debug)]
pub struct UtilitiesHandler;

impl CommandHandler for UtilitiesHandler {
    fn execute(&self, args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            match args.args.first().map(|s| s.as_str()) {
                Some("date") => {
                    println!("Current date: {}", chrono::Local::now().format("%Y-%m-%d"));
                    Ok(())
                }
                Some("time") => {
                    println!("Current time: {}", chrono::Local::now().format("%H:%M:%S"));
                    Ok(())
                }
                Some("datetime") => {
                    println!(
                        "Current date and time: {}",
                        chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
                    );
                    Ok(())
                }
                _ => {
                    println!("Unknown utility command. Available commands: date, time, datetime");
                    Ok(())
                }
            }
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "utility" || command == "utils"
    }
}

// Contact groups handler
#[derive(Debug)]
pub struct ContactGroupsHandler;

impl CommandHandler for ContactGroupsHandler {
    fn execute(&self, args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            match args.args.first().map(|s| s.as_str()) {
                Some("create") => {
                    if args.args.len() < 3 {
                        println!("Not enough arguments for contact group create command");
                        println!("Usage: ducktape contacts create <group_name> <emails...>");
                        return Ok(());
                    }

                    let group_name = &args.args[1];
                    let emails: Vec<String> = args.args.iter().skip(2).cloned().collect();

                    if emails.is_empty() {
                        println!("No email addresses provided");
                        return Ok(());
                    }

                    // Validate email addresses
                    for email in &emails {
                        if !crate::calendar::validate_email(email) {
                            println!("Invalid email address: {}", email);
                            return Ok(());
                        }
                    }

                    // Create contact group
                    let result = crate::contact_groups::create_group(group_name, &emails);
                    match result {
                        Ok(_) => {
                            println!(
                                "Created contact group '{}' with {} members",
                                group_name,
                                emails.len()
                            );
                        }
                        Err(e) => {
                            println!("Failed to create contact group: {}", e);
                        }
                    }
                    Ok(())
                }
                Some("list") => {
                    match crate::contact_groups::list_groups() {
                        Ok(groups) => {
                            if groups.is_empty() {
                                println!("No contact groups found");
                            } else {
                                println!("Available contact groups:");
                                for group in groups {
                                    println!("  - {}", group);
                                }
                            }
                        }
                        Err(e) => {
                            println!("Failed to list contact groups: {}", e);
                        }
                    }
                    Ok(())
                }
                Some("show") => {
                    if args.args.len() < 2 {
                        println!("Not enough arguments for contact group show command");
                        println!("Usage: ducktape contacts show <group_name>");
                        return Ok(());
                    }

                    let group_name = &args.args[1];
                    match crate::contact_groups::get_group(group_name) {
                        Ok(Some(members)) => {
                            println!("Members of contact group '{}':", group_name);
                            for member in members {
                                println!("  - {}", member);
                            }
                        }
                        Ok(None) => {
                            println!("Contact group '{}' not found", group_name);
                        }
                        Err(e) => {
                            println!("Failed to show contact group: {}", e);
                        }
                    }
                    Ok(())
                }
                _ => {
                    println!("Unknown contacts command. Available commands: create, list, show");
                    Ok(())
                }
            }
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "contacts" || command == "contact"
    }
}

// Version handler
#[derive(Debug)]
pub struct VersionHandler;

impl CommandHandler for VersionHandler {
    fn execute(&self, _args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            const VERSION: &str = env!("CARGO_PKG_VERSION");
            println!("DuckTape v{}", VERSION);
            println!(
                "A tool for interacting with Apple Calendar, Notes, and Reminders via the command line."
            );
            println!("© 2024-2025 DuckTape Team");
            Ok(())
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "version" || command == "--version" || command == "-v"
    }
}

// Help handler
#[derive(Debug)]
pub struct HelpHandler;

impl CommandHandler for HelpHandler {
    fn execute(&self, _args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            print_help()?;
            Ok(())
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "help" || command == "--help" || command == "-h"
    }
}

// Exit handler
#[derive(Debug)]
pub struct ExitHandler;

impl CommandHandler for ExitHandler {
    fn execute(&self, _args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            println!("Exiting DuckTape...");
            std::process::exit(0);
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "exit" || command == "quit"
    }
}

// Reminder handler (using Apple's terminology "Reminders" for the app)
#[derive(Debug)]
pub struct ReminderHandler;

impl CommandHandler for ReminderHandler {
    fn execute(&self, args: CommandArgs) -> Pin<Box<dyn Future<Output = Result<()>> + '_>> {
        Box::pin(async move {
            match args.args.first().map(|s| s.as_str()) {
                Some("create") | Some("add") => {
                    if args.args.len() < 2 {
                        println!("Not enough arguments for reminder create command");
                        println!("Usage: ducktape reminder create <title> [list1] [list2] ...");
                        return Ok(());
                    }

                    let title = &args.args[1];

                    // Create a new ReminderConfig with the title
                    let mut config = crate::reminder::ReminderConfig::new(title);

                    // Set lists if provided in arguments (args[2] and beyond are list names)
                    if args.args.len() > 2 {
                        // Only collect lists that don't start with "--" (those are flags)
                        let list_names: Vec<&str> = args.args[2..]
                            .iter()
                            .map(|s| s.as_str())
                            .filter(|s| !s.starts_with("--"))
                            .collect();

                        if !list_names.is_empty() {
                            config.lists = list_names;
                        }
                    }

                    // Process standard flags (like --remind)
                    // Look for --remind flag in both formats: as key in flags HashMap or as commandline arg
                    let reminder_time = if let Some(Some(time)) = args.flags.get("remind") {
                        // Found in the flags HashMap
                        debug!("Found reminder time in flags HashMap: {}", time);
                        Some(time.as_str())
                    } else if let Some(remind_idx) =
                        args.args.iter().position(|arg| arg == "--remind")
                    {
                        // Found as a commandline arg
                        if remind_idx + 1 < args.args.len() {
                            let time = &args.args[remind_idx + 1];
                            debug!("Found reminder time as arg: {}", time);
                            Some(time.trim_matches('"').trim_matches('\''))
                        } else {
                            None
                        }
                    } else {
                        None
                    };

                    if let Some(time_str) = reminder_time {
                        debug!("Setting reminder time: {}", time_str);
                        config.reminder_time = Some(time_str);
                    }

                    // Set notes if provided via --notes flag (similar approach as reminder time)
                    let notes = if let Some(Some(note_text)) = args.flags.get("notes") {
                        // Found in the flags HashMap
                        Some(note_text.clone())
                    } else if let Some(notes_idx) =
                        args.args.iter().position(|arg| arg == "--notes")
                    {
                        // Found as a commandline arg
                        if notes_idx + 1 < args.args.len() {
                            Some(args.args[notes_idx + 1].clone())
                        } else {
                            None
                        }
                    } else {
                        None
                    };

                    if let Some(note_text) = notes {
                        debug!("Setting notes: {}", note_text);
                        config.notes =
                            Some(note_text.trim_matches('"').trim_matches('\'').to_string());
                    }

                    debug!("Final reminder config: {:?}", config);

                    // Use await with the async create_reminder function
                    match crate::reminder::create_reminder(config).await {
                        Ok(_) => {
                            println!("Reminder '{}' created successfully", title);
                            Ok(())
                        }
                        Err(e) => {
                            println!("Failed to create reminder: {}", e);
                            Err(anyhow!("Failed to create reminder: {}", e))
                        }
                    }
                }
                Some("list") => {
                    // Implementation for listing reminders would go here using async/await
                    println!("Listing reminders... (not implemented yet)");
                    Ok(())
                }
                Some("delete") => {
                    // Implementation for deleting reminders would go here using async/await
                    println!("Deleting reminder... (not implemented yet)");
                    Ok(())
                }
                _ => {
                    println!(
                        "Unknown reminder command. Available commands: create/add, list, delete"
                    );
                    Ok(())
                }
            }
        })
    }

    fn can_handle(&self, command: &str) -> bool {
        command == "reminder" || command == "reminders"
    }
}

// Print help information
pub fn print_help() -> Result<()> {
    println!("DuckTape - A tool for interacting with Apple Calendar, Notes, and Reminders");
    println!();
    println!("USAGE:");
    println!("  ducktape [COMMAND] [SUBCOMMAND] [OPTIONS]");
    println!();
    println!("COMMANDS:");
    println!("  calendar  Manage calendar events");
    println!("  todo      Manage todo items");
    println!("  notes     Manage notes");
    println!("  config    Manage configuration");
    println!("  contacts  Manage contact groups");
    println!("  utils     Utility commands");
    println!("  help      Show this help message");
    println!("  version   Show version information");
    println!("  exit      Exit the application");
    println!();
    println!("For more information on a specific command, run:");
    println!("  ducktape [COMMAND] --help");
    println!();
    println!("EXAMPLES:");
    println!("  ducktape calendar create \"Meeting with Team\" 2025-04-15 10:00 11:00");
    println!("  ducktape todo add \"Buy groceries\" tomorrow 18:00");
    println!("  ducktape notes create \"Meeting Notes\" \"Points discussed in the meeting\"");
    println!("  ducktape config set calendar.default \"Personal\"");
    Ok(())
}

/// Helper function to properly process contact names from command string
/// Handles both comma-separated lists and multi-word contact names
fn process_contact_string(contacts_str: &str) -> Vec<&str> {
    debug!("Processing contact string: '{}'", contacts_str);

    // First trim any surrounding quotes that might have been preserved
    let trimmed = contacts_str.trim_matches('"').trim_matches('\'').trim();
    debug!("After trimming quotes: '{}'", trimmed);

    // Split by commas, handling both single contact and multiple contacts
    let contacts: Vec<&str> =
        trimmed.split(',').map(|s| s.trim()).filter(|s| !s.is_empty()).collect();

    debug!("Detected contacts: {:?}", contacts);
    contacts
}

// Command processor that manages handlers and executes commands
#[derive(Debug)]
pub struct CommandProcessor {
    handlers: Vec<Box<dyn CommandHandler>>,
}

impl CommandProcessor {
    pub fn new() -> Self {
        let handlers: Vec<Box<dyn CommandHandler>> = vec![
            Box::new(CalendarHandler),
            Box::new(TodoHandler),
            Box::new(NotesHandler),
            Box::new(ConfigHandler),
            Box::new(UtilitiesHandler),
            Box::new(ContactGroupsHandler),
            Box::new(VersionHandler),
            Box::new(HelpHandler),
            Box::new(ExitHandler),
            Box::new(ReminderHandler),
        ];
        Self { handlers }
    }

    pub async fn execute(&self, args: CommandArgs) -> Result<()> {
        debug!("Attempting to execute command: {}", args.command);
        debug!("Parsed arguments: {:?}", args.args);
        debug!("Parsed flags: {:?}", args.flags);

        let command_name = args.command.clone(); // Clone the command name for logging
        let args_debug = format!("{:?}", args.args); // Format args for debug logging

        for handler in &self.handlers {
            if handler.can_handle(&command_name) {
                info!("Executing command '{}' with arguments: {}", command_name, args_debug);

                // Use the args directly - our tokenizer should have handled quoted strings correctly
                let args_to_use = args.clone();

                match handler.execute(args_to_use).await {
                    Ok(()) => {
                        debug!("Command '{}' executed successfully", command_name);
                        return Ok(());
                    }
                    Err(e) => {
                        log::error!("Failed to execute command '{}': {:?}", command_name, e);
                        return Err(e);
                    }
                }
            }
        }

        warn!("Unrecognized command: {}", command_name);
        println!("Unrecognized command. Type 'help' for a list of available commands.");
        Ok(())
    }
}

impl Default for CommandProcessor {
    fn default() -> Self {
        Self::new()
    }
}

/// Centralized function to resolve contacts from input
pub fn resolve_contacts(input: &str) -> Vec<String> {
    let mut contacts = Vec::new();

    debug!("resolve_contacts called with input: '{}'", input);

    // Example logic for resolving contacts with exact matching
    let name_to_emails = vec![
        (
            "Shaun Stuart",
            vec!["joe.duck@gmail.com", "joe.duck@live.com", "joe@ducktapeai.com"],
        ),
        (
            "Joe Bloggs",
            vec![
                "joe.blogs@gmail.com",
                "joe.blogs@company.com",
                "joe.blogs@live.com",
                "joe@freelancer.com",
            ],
        ),
        (
            "Jane Doe",
            vec![
                "jane.doe@gmail.com",
                "jane.doe@company.com",
                "jane.doe@live.com",
                "jane@freelancer.com",
            ],
        ),
    ];

    for (name, emails) in name_to_emails {
        debug!("Checking if '{}' matches '{}'", input.trim(), name);
        if input.trim().eq_ignore_ascii_case(name) {
            debug!("Match found for '{}', adding emails: {:?}", name, emails);
            contacts.extend(emails.into_iter().map(String::from));
        }
    }

    debug!("Resolved contacts: {:?}", contacts);
    contacts
}

/// Standardized input preprocessing function
pub fn preprocess_input(input: &str) -> String {
    input.trim().to_lowercase()
}
