# Minimal file so Python buildpack detects a Python app.
# We don't actually run this; Cloud Run will run the Procfile command instead.
if __name__ == "__main__":
    print("Buildpack detection shim")
