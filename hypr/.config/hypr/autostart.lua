-- Extra autostart processes.
-- Ensure fcitx5 input method service is started for dead keys and compose support (ç, ã, etc.)
o.exec_on_start("systemctl --user start omarchy-fcitx5.service")
