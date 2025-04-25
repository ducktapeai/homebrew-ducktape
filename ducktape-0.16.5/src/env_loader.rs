use anyhow::Result;
use log::{error, info};
use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::Path;

pub struct EnvLoader;

impl EnvLoader {
    pub fn load_env_file<P: AsRef<Path>>(path: P) -> Result<()> {
        let file = File::open(path)?;
        let reader = BufReader::new(file);

        for line in reader.lines() {
            if let Ok(line) = line {
                if line.starts_with('#') || line.trim().is_empty() {
                    continue;
                }

                if let Some((key, value)) = line.split_once('=') {
                    std::env::set_var(key.trim(), value.trim());
                }
            }
        }

        Ok(())
    }
}

// Load environment variables from a .env file
pub fn load_env_file(path: &str) -> HashMap<String, String> {
    let mut vars = HashMap::new();

    let env_path = Path::new(path);
    if !env_path.exists() {
        info!("No .env file found at {}", path);
        return vars;
    }

    match File::open(env_path) {
        Ok(file) => {
            let reader = BufReader::new(file);

            for line in reader.lines() {
                if let Ok(line) = line {
                    // Skip comments and empty lines
                    let trimmed = line.trim();
                    if trimmed.is_empty() || trimmed.starts_with('#') {
                        continue;
                    }

                    // Parse KEY=VALUE format
                    if let Some(pos) = trimmed.find('=') {
                        let key = trimmed[0..pos].trim().to_string();
                        let value = trimmed[pos + 1..].trim().to_string();

                        // Handle quoted values
                        let cleaned_value = match (value.starts_with('"') && value.ends_with('"'))
                            || (value.starts_with('\'') && value.ends_with('\''))
                        {
                            true => value[1..value.len() - 1].to_string(),
                            false => value,
                        };

                        vars.insert(key, cleaned_value);
                    }
                }
            }

            info!("Loaded {} environment variables from {}", vars.len(), path);
        }
        Err(e) => {
            error!("Failed to open .env file: {}", e);
        }
    }

    vars
}

// Set environment variables from a HashMap
pub fn set_env_vars(vars: &HashMap<String, String>) {
    for (key, value) in vars {
        std::env::set_var(key, value);
        info!("Set environment variable from .env: {}", key);
    }
}

// Load and set environment variables in one function
pub fn load_and_set_env(path: &str) -> HashMap<String, String> {
    let vars = load_env_file(path);
    set_env_vars(&vars);
    vars
}
