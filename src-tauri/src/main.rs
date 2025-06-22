// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
use tauri_plugin_deep_link::DeepLinkExt;
use tauri_plugin_shell::process::CommandEvent;
use tauri_plugin_shell::ShellExt;

fn main() {
    #[allow(unused_mut)]
    let mut builder = tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_deep_link::init());

    #[cfg(desktop)]
    {
        builder = builder.plugin(tauri_plugin_single_instance::init(|_app, argv, _cwd| {
          println!("a new app instance was opened with {argv:?} and the deep link event was already triggered");
          // when defining deep link schemes at runtime, you must also check `argv` here
        }));
    }

    builder
        .plugin(tauri_plugin_log::Builder::new().build())
        .setup(|app| {
            #[cfg(any(target_os = "linux", all(debug_assertions, windows)))]
            app.deep_link().register_all()?;

            app.deep_link().on_open_url(|event| {
                dbg!(event.urls());
            });

            start_server(app.handle());
            check_server_started();
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
fn start_server(app: &tauri::AppHandle) {
    let sidecar_command = app
        .shell()
        .sidecar("desktop")
        .expect("failed to setup `desktop` sidecar");

    let (mut rx, mut _child) = sidecar_command
        .spawn()
        .expect("Failed to spawn packaged node");

    tauri::async_runtime::spawn(async move {
        while let Some(event) = rx.recv().await {
            if let CommandEvent::Stdout(line_bytes) = event {
                let line = String::from_utf8_lossy(&line_bytes);
                println!("{}", line);
            }
        }
    });
}

fn check_server_started() {
    let sleep_interval = std::time::Duration::from_millis(200);
    let host = "localhost".to_string();
    let port = "4000".to_string();
    let addr = format!("{}:{}", host, port);
    println!(
        "Waiting for your phoenix dev server to start on {}...",
        addr
    );
    loop {
        if std::net::TcpStream::connect(addr.clone()).is_ok() {
            break;
        }
        std::thread::sleep(sleep_interval);
    }
}
