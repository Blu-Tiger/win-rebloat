import os
import sys
import shutil
import tempfile
import requests
import subprocess
import re
import json


def optional_select_parser(optional_select):
    """
    Parse the selection string
    """
    if not optional_select or not str(optional_select).strip():
        return {}
    parsed = {}
    groups = [g.strip() for g in optional_select.split(',') if g.strip()]
    for group in groups:
        match = re.match(r'^(.*?):(.*)$', group)
        if match:
            key = match.group(1).strip()
            values = [v.strip() for v in match.group(2).split(':') if v.strip()]
            parsed[key] = values
        else:
            parsed[group] = []
    return parsed


def generate_partial_file_path(app, dl_dir):
    """_summary_
    Generate the temp file path without the extension
    """
    name = app['name'].lower()
    name = name.replace(' ', '_')
    name = re.sub(r'[\\/:*?"<>|]', '', name)
    name = name.strip()
    part_file_path = os.path.join(dl_dir, name)
    return part_file_path


def download_from_github(app, part_file_path):
    """
    Download from a github repo
    """
    try:
        url = f"https://api.github.com/repos/{app['repo']}/releases/latest"
        response = requests.get(url, headers={"User-Agent": "Python"})
        response.raise_for_status()
        data = response.json()
        assets = data.get("assets", [])
        files_to_download = [
            a for a in assets if re.search(app["file_pattern"], a["name"])
        ]
        if not files_to_download:
            print(f"No files matched the pattern '{app['file_pattern']}'.")
            return None
        file = files_to_download[0]
        file_url = file['browser_download_url']
        print(f"Downloading '{file['name']}' from GitHub...")
        file_path = part_file_path + os.path.splitext(file['name'])[1]
        with requests.get(file_url, stream=True) as r:
            r.raise_for_status()
            with open(file_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        print(f"'{file['name']}' downloaded successfully to '{file_path}'.")
        return file_path
    except Exception as e:
        print(f"Error occurred: {e}", file=sys.stderr)
        return None


def download_from_website(app, part_file_path):
    """
    Executes the provided PowerShell function (as a string) in app['get_url_function']
    and expects it to output a URL to stdout.
    """
    try:
        get_url_function_ps = app['get_url_function']
        ps_command = f"""
        {get_url_function_ps}
        Get-Url
        """
        completed = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_command],
            capture_output=True,
            text=True,
            check=True,
        )
        file_url = completed.stdout.strip().splitlines()[
            -1
        ]  # Get the last line output as URL
        orig_file_name = os.path.basename(file_url)
        file_path = part_file_path + os.path.splitext(orig_file_name)[1]
        print(f"Downloading '{orig_file_name}' from '{file_url}'...")
        with requests.get(file_url, stream=True) as r:
            r.raise_for_status()
            with open(file_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        return file_path
    except Exception as e:
        print(f"Error occurred: {e}", file=sys.stderr)
        return None


def msi_installer(file_path):
    try:
        subprocess.run(['msiexec.exe', '/i', file_path, '/qn'], check=True)
    except Exception as e:
        print(f"Error occurred: {e}", file=sys.stderr)


def exe_installer(file_path, app):
    try:
        args = app.get('install_args', '')
        arg_list = args.split() if isinstance(args, str) else args
        if isinstance(arg_list, list):
            subprocess.run([file_path] + arg_list, check=True)
        else:
            subprocess.run([file_path] + [arg_list], check=True)
    except Exception as e:
        print(f"Error occurred: {e}", file=sys.stderr)


def msixbundle_installer(file_path):
    try:
        subprocess.run(
            [
                "powershell",
                "-Command",
                f'Add-AppxProvisionedPackage -Online -PackagePath "{file_path}" -SkipLicense',
            ],
            check=True,
        )
    except Exception as e:
        print(f"Error occurred: {e}", file=sys.stderr)


def win_rebloat(
    config_path="./config.toml",
    get_info=False,
    get_object_config=False,
    get_json_config=False,
    config=None,
    optional_select=None,
):
    """Install all the deault apps and the selected apps

    Args:
        config_path (str, optional): Path to the config file. Defaults to "./config.toml".
        get_info (bool, optional): Show available apps in human-readable format.
        get_object_config (bool, optional): Output config as Python object.
        get_json_config (bool, optional): Output config as JSON string.
        config (str, optional): Raw config content when not using file.
        optional_select (str, optional): Selection string for optional apps.
    """
    # Load config
    try:
        content = config
        if content is None:
            with open(config_path, "r", encoding="utf-8") as f:
                content = f.read()

        try:
            config_object = json.loads(content)
            print("Configuration parsed as JSON", file=sys.stderr)
        except json.JSONDecodeError:
            try:
                import toml

                config_object = toml.loads(content)
                print("Configuration parsed as TOML", file=sys.stderr)
            except toml.TomlDecodeError as e:
                raise RuntimeError("Unsupported configuration format!")

        apps = config_object.get('apps', {})
        selectable_apps = config_object.get('selectable_apps', {})
        app_categories = list(apps.keys())
        selectable_categories = list(selectable_apps.keys())

        if optional_select is not None:
            parsed_select = optional_select_parser(optional_select)
        else:
            parsed_select = None

        for app_categ in selectable_categories:
            app_list = selectable_apps[app_categ]
            if parsed_select and app_categ in parsed_select:
                for app in app_list:
                    app['selected'] = False
                for select in parsed_select[app_categ]:
                    for app in app_list:
                        if select.lower() == app['name'].lower():
                            app['selected'] = True
            else:
                for app in app_list:
                    if 'selected' not in app or app['selected'] is None:
                        app['selected'] = False

    except Exception as e:
        print(f"Failed to load config: {e}", file=sys.stderr)
        sys.exit(1)

    if get_info:
        print("\n=== Available Bloatware ===\n")
        print("\n= Defaults =\n")
        for app_categ in app_categories:
            app_list = apps[app_categ]
            if len(app_list) == 0:
                print("  No applications available.")
                continue
            print(f"{app_categ.capitalize()}:")
            for app in app_list:
                print(f"    - {app['name']}")
            print()

        print("\n= Selectable =\n")
        for app_categ in selectable_categories:
            app_list = selectable_apps[app_categ]
            if len(app_list) == 0:
                print("  No applications available.")
                continue
            print(f"{app_categ.capitalize()}:")
            for app in app_list:
                if app.get('selected', False):
                    print(f"    - {app['name']} (selected)")
                else:
                    print(f"    - {app['name']}")
            print()
        return

    if get_object_config:
        import pprint

        pprint.pprint(config_object)
        return

    if get_json_config:
        print(json.dumps(config_object, indent=2))
        return

    # Installation process
    temp = os.path.join(tempfile.gettempdir(), 'rebloat')
    if not os.path.exists(temp):
        os.makedirs(temp)
        print(f"Folder created: {temp}")

    # Install default apps
    for app_categ in app_categories:
        app_list = apps[app_categ]
        if len(app_list) == 0:
            print(f"No applications available for category '{app_categ}'.")
            continue
        for app in app_list:
            part_file_path = generate_partial_file_path(app, temp)
            if app['type'] == "github":
                file_path = download_from_github(app, part_file_path)
            elif app['type'] == "website":
                file_path = download_from_website(app, part_file_path)
            else:
                print(f"Unknown app type: '{app['type']}'", file=sys.stderr)
                continue
            if not file_path or not os.path.exists(file_path):
                print(f"Failed to download file for '{app['name']}'.", file=sys.stderr)
                continue
            print(f"Installing '{app['name']}'...")
            ext = os.path.splitext(file_path)[1].lower().strip('.')
            if ext == "msi":
                msi_installer(file_path)
            elif ext == "exe":
                exe_installer(file_path, app)
            elif ext == "msixbundle":
                msixbundle_installer(file_path)
            else:
                print(f"Unknown install file type: '{ext}'", file=sys.stderr)

    # Install selectable apps
    for app_categ in selectable_categories:
        app_list = selectable_apps[app_categ]
        if len(app_list) == 0:
            print(f"No applications available for category '{app_categ}'.")
            continue
        for app in app_list:
            if not app.get('selected', False):
                continue
            part_file_path = generate_partial_file_path(app, temp)
            if app['type'] == "github":
                file_path = download_from_github(app, part_file_path)
            elif app['type'] == "website":
                file_path = download_from_website(app, part_file_path)
            else:
                print(f"Unknown app type: '{app['type']}'", file=sys.stderr)
                continue
            if not file_path or not os.path.exists(file_path):
                print(f"Failed to download file for '{app['name']}'.", file=sys.stderr)
                continue
            print(f"Installing '{app['name']}'...")
            ext = os.path.splitext(file_path)[1].lower().strip('.')
            if ext == "msi":
                msi_installer(file_path)
            elif ext == "exe":
                exe_installer(file_path, app)
            elif ext == "msixbundle":
                msixbundle_installer(file_path)
            else:
                print(f"Unknown install file type: '{ext}'", file=sys.stderr)

    # Cleanup
    if os.path.exists(temp):
        try:
            shutil.rmtree(temp)
            print("Temporary files cleaned up.")
        except Exception as e:
            print(f"Failed to clean up temporary files: {e}", file=sys.stderr)
    else:
        print("No temporary files to clean up.")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Win-Rebloat Python Port")
    parser.add_argument(
        "--config", type=str, default=None, help="Raw configuration string"
    )
    parser.add_argument(
        "--config-path", type=str, default="./config.toml", help="Path to config file"
    )
    parser.add_argument("--get-info", action="store_true", help="Show available apps")
    parser.add_argument(
        "--get-object-config",
        action="store_true",
        help="Output config as Python object",
    )
    parser.add_argument(
        "--get-json-config", action="store_true", help="Output config as JSON"
    )
    parser.add_argument("--optional-select", type=str, help="Optional select string")
    args = parser.parse_args()

    win_rebloat(
        config_path=args.config_path,
        get_info=args.get_info,
        get_object_config=args.get_object_config,
        get_json_config=args.get_json_config,
        config=args.config,
        optional_select=args.optional_select,
    )
