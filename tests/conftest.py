import os

# Force CPU for tests unless explicitly overridden.
os.environ["TENSOR_DEVICE"] = "cpu"
