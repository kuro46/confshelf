use std::env;
use std::process;
use std::fmt;
use std::iter::FromIterator;
use std::collections::VecDeque;
use std::io::{self, Read, Write};
use std::fs::{self, File};
use std::os::unix;
use std::path::{Path, PathBuf};
use serde::{Serialize, Deserialize};

const VERSION: &'static str = env!("CARGO_PKG_VERSION");

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 || args[1] == "help" {
        help();
        return;
    }
    match args[1].as_ref() {
        "version" => version(),
        "setup" => setup(),
        "selfupdate" => selfupdate(),
        _ => {
            println!("Unknown command.");
            println!();
            help();
        },
    }
}

fn version() {
    println!("confshelf v{}", VERSION);
}

fn selfupdate() {
    todo!()
}

fn setup() {
    let recipe = match Recipe::load("./recipe.toml") {
        Ok(recipe) => recipe,
        Err(err) => {
            eprintln!("Error: Failed to load recipe: {}", err);
            process::exit(1);
        }
    };
    let mut queue = VecDeque::from_iter(&recipe.links);
    while let Some(link) = queue.pop_front() {
        println!("Creating symlink {:?} that points to {:?}", link.symlink, link.target);
        let result = create_link(link, false);
        if !result.is_err() {
            println!("  Created!");
            continue;
        }
        let err = result.unwrap_err();
        match err {
            LinkCreationError::SymlinkPathIsNotDirOrSymlink => {
                let answer = ask(&format!(
                    "  Do you want to overwrite symlink path ({:?}) that already exists? [y/N] ",
                    link.symlink
                ));
                if answer == Answer::Yes {
                    queue.push_back(link);
                }
            },
            other => {
                eprintln!("  Error: {}", other);
            }
        }
    }
    println!("");
    if let Some(script) = &recipe.script_on_setup {
        println!("Symlink creation finished! Executing script '{}'", script);
        let mut child = match process::Command::new(script).spawn() {
            Ok(child) => child,
            Err(err) => {
                eprintln!("  Error: Failed to execute script: {:?}", err);
                process::exit(1);
            },
        };
        let exit_status = match child.wait() {
            Ok(exit_status) => exit_status,
            Err(err) => {
                eprintln!("  Error: While waiting process exit: {:?}", err);
                process::exit(1);
            },
        };
        if !exit_status.success() {
            match exit_status.code() {
                None => eprintln!("  Error: Process terminated by signal"),
                Some(code) => eprintln!("  Error: Process exited with code {}", code),
            };
            process::exit(1);
        }
    }
    println!("Setup finished!");
}

fn ask(prompt: &str) -> Answer {
    io::stdout().write_all(prompt.as_bytes())
        .expect("Failed to write prompt");
    io::stdout().flush()
        .expect("Failed to flush stdout");
    let mut buf = String::new();
    io::stdin().read_line(&mut buf)
        .expect("Couldn't read line");
    let buf = buf.to_lowercase();
    let buf = buf.trim();
    if buf == "y" || buf == "yes" {
        Answer::Yes
    } else {
        Answer::No
    }
}

#[derive(Debug, Eq, PartialEq)]
enum Answer {
    Yes,
    No
}

#[derive(Debug)]
enum LinkCreationError {
    IOError{ msg: String, err: io::Error },
    TargetNotExists,
    SymlinkPathIsDir,
    SymlinkPathIsNotDirOrSymlink,
}

impl fmt::Display for LinkCreationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            LinkCreationError::TargetNotExists => {
                write!(f, "Target file not exists")
            },
            LinkCreationError::SymlinkPathIsDir => {
                write!(f, "Symlink path is a directory")
            },
            LinkCreationError::SymlinkPathIsNotDirOrSymlink => {
                write!(f, "Symlink path is not either directory or symbolic link")
            },
            LinkCreationError::IOError { msg, err } => {
                write!(f, "IO error: {}: {:?}", msg, err.kind())?;
                if let Some(os_err) = err.raw_os_error() {
                    write!(f, " (OS error: {})", os_err)
                } else {
                    Ok(())
                }
            }
        }
    }
}

fn create_link(link: &Link, force: bool) -> Result<(), LinkCreationError> {
    // Confirm only when symlink is already exists and it is not symbolic link

    let target_path = &link.target;
    if !target_path.exists() {
        return Err(LinkCreationError::TargetNotExists);
    }
    let symlink_path = &link.symlink;
    if !force && symlink_path.exists() {
        let symlink_meta = fs::symlink_metadata(symlink_path).map_err(|e| LinkCreationError::IOError {
            msg: "Failed to retrieve metadata".to_string(),
            err: e,
        })?;
        if symlink_meta.file_type().is_dir() {
            return Err(LinkCreationError::SymlinkPathIsDir);
        }
        if !symlink_meta.file_type().is_symlink() {
            return Err(LinkCreationError::SymlinkPathIsNotDirOrSymlink);
        }
    }
    // remove if already exists
    if symlink_path.exists() {
        fs::remove_file(symlink_path).map_err(|e| LinkCreationError::IOError {
            msg: "Failed to remove symlink path".to_string(),
            err: e,
        })?;
    }
    // create symlink
    unix::fs::symlink(target_path, symlink_path).map_err(|e| LinkCreationError::IOError {
        msg: "Failed to create symlink".to_string(),
        err: e,
    })?;
    Ok(())
}

fn help() {
    let msg = r#"confshelf help       - Print this message
confshelf setup      - Execute setup according to recipe.toml
confshelf version    - Print version
confshelf selfupdate - Update executable
"#;
    println!("{}", msg);
}

#[derive(Debug)]
enum RecipeLoadError {
    IOError { msg: String, err: io::Error },
    FormatError(toml::de::Error)
}

impl fmt::Display for RecipeLoadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RecipeLoadError::FormatError(err) => {
                write!(f, "Recipe format error: {}", err)
            },
            RecipeLoadError::IOError { msg, err } => {
                write!(f, "IO error: {}: {:?}", msg, err.kind())?;
                if let Some(os_err) = err.raw_os_error() {
                    write!(f, " (OS error: {})", os_err)
                } else {
                    Ok(())
                }
            }
        }
    }
}

#[derive(Debug, Eq, PartialEq, Clone, Serialize, Deserialize)]
struct Recipe {
    script_on_setup: Option<String>,
    links: Vec<Link>,
}

impl Recipe {
    fn load<P: AsRef<Path>>(path: P) -> Result<Recipe, RecipeLoadError> {
        let mut file = File::open(path).map_err(|e| RecipeLoadError::IOError {
            msg: "Cannot open recipe file".to_string(),
            err: e,
        })?;
        let mut file_content = String::new();
        file.read_to_string(&mut file_content).map_err(|e| RecipeLoadError::IOError {
            msg: "Cannot read recipe file".to_string(),
            err: e,
        })?;
        let recipe: Recipe = toml::from_str(&file_content).map_err(|e| RecipeLoadError::FormatError(e))?;
        return Ok(recipe);
    }
}

#[derive(Debug, Eq, PartialEq, Clone, Serialize, Deserialize)]
struct Link {
    symlink: PathBuf,
    target: PathBuf,
}

#[cfg(test)]
mod tests {

    use std::env;
    use std::io::{Write};
    use std::fs::{self, File};
    use std::path::PathBuf;
    use std::os::unix;
    use super::*;
    use serial_test::serial;

    fn init_test() {
        let test_dir = path_test_dir();
        if test_dir.exists() && test_dir.exists() {
            fs::remove_dir_all(test_dir).unwrap();
        }
        fs::create_dir(path_test_dir()).unwrap();
        let mut just_regular_file = File::create(path_just_regular_file()).unwrap();
        just_regular_file.write_all(b"Just a content").unwrap();
        unix::fs::symlink(path_just_regular_file(), path_just_symbolic_link()).unwrap();
    }

    fn path_test_dir() -> PathBuf {
        let mut buf = PathBuf::from(env::current_dir().unwrap());
        buf.push("test_dir");
        buf
    }

    fn path_just_symbolic_link() -> PathBuf {
        let mut buf = PathBuf::from(path_test_dir());
        buf.push("just_symbolic_link");
        buf
    }

    fn path_just_regular_file() -> PathBuf {
        let mut buf = PathBuf::from(path_test_dir());
        buf.push("just_regular_file");
        buf
    }

    #[test]
    #[serial]
    fn create_link_new_symlink() {
        init_test();
        let new_symlink_path = path_test_dir().join("new_symlink");
        let link = Link {
            symlink: new_symlink_path.clone(),
            target: path_just_regular_file(),
        };
        create_link(&link, false).unwrap();
        let link_read = fs::read_link(new_symlink_path).unwrap();
        assert_eq!(link_read.file_name(), path_just_regular_file().file_name());
    }

    // Update symlink
    #[test]
    #[serial]
    fn create_link_replace_symlink() {
        init_test();
        let new_target_file_path = path_test_dir().join("new_target_file");
        File::create(&new_target_file_path).unwrap();
        let link = Link {
            symlink: path_just_symbolic_link(),
            target: new_target_file_path.clone(),
        };
        create_link(&link, false).unwrap();
        let link_read = fs::read_link(path_just_symbolic_link()).unwrap();
        assert_eq!(new_target_file_path.file_name(), link_read.file_name());
    }

    #[test]
    #[serial]
    fn create_link_target_not_exists() {
        init_test();
        let link = Link {
            symlink: PathBuf::from("this_is_symlink"),
            target: PathBuf::from("foobar"),
        };
        let err = create_link(&link, false).unwrap_err();
        assert_eq!(format!("{}", err), "Target file not exists");
    }

    #[test]
    #[serial]
    fn create_link_symlink_is_dir() {
        init_test();
        let path_dir = path_test_dir().join("foo_dir");
        fs::create_dir(&path_dir).unwrap();
        let link = Link {
            symlink: path_dir,
            target: path_just_regular_file(),
        };
        let err = create_link(&link, false).unwrap_err();
        assert_eq!(format!("{}", err), "Symlink path is a directory");
    }

    #[test]
    #[serial]
    fn create_link_symlink_is_regular_file() {
        init_test();
        let path_regular_file = path_test_dir().join("foo_file");
        File::create(&path_regular_file).unwrap();
        let link = Link {
            symlink: path_regular_file,
            target: path_just_regular_file(),
        };
        let err = create_link(&link, false).unwrap_err();
        assert_eq!(format!("{}", err), "Symlink path is not either directory or symbolic link");
    }
}
