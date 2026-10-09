from pathlib import Path


def test_android_manifest_allows_lan_http_api() -> None:
    manifest = Path(__file__).resolve().parents[3] / "frontend" / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    content = manifest.read_text(encoding="utf-8")

    assert "android.permission.INTERNET" in content
    assert "android:usesCleartextTraffic=\"true\"" in content