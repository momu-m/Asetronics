int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
        _In_ wchar_t *command_line, _In_ int show_command) {
// Fenster-Eigenschaften
WNDCLASSEXW window_class = {0};
window_class.cbSize = sizeof(WNDCLASSEXW);
window_class.lpszClassName = L"FLUTTER_RUNNER_WIN32_WINDOW";
window_class.hInstance = instance;
window_class.lpfnWndProc = Win32Window::WndProc;

RegisterClassExW(&window_class);

// Flutter-Einstellungen
DartProject project(L"data");
FlutterViewController* flutter_controller =
        new FlutterViewController(project);
Win32Window::Point origin(10, 10);
Win32Window::Size size(1280, 720);
Win32Window::CreateAndShow(L"Asetronics AG", origin, size);

Run();

return 0;
}