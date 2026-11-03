{
  writeShellApplication,
  uv,
  python3,
}:
writeShellApplication {
  name = "colab";
  runtimeInputs = [
    uv
    python3
  ];
  text = ''
    umask 077
    # All dependency versions and download hashes are in uv.lock. The mutable
    # environment lives outside the store; bootstrap warms it with `colab version`.
    export UV_PROJECT_ENVIRONMENT="$HOME/.local/share/nix-colab/venv"
    export UV_PYTHON_DOWNLOADS=never
    exec uv run --frozen --no-dev --project ${./colab} --python ${python3}/bin/python3 colab "$@"
  '';
}
