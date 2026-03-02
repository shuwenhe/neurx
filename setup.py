import os
import sys
import sysconfig
from pathlib import Path

from setuptools import Extension, setup, find_packages
from setuptools.command.build_ext import build_ext

import numpy as np


def _cuda_home():
    env = os.environ.get("CUDA_HOME") or os.environ.get("CUDA_PATH")
    if env:
        return Path(env)
    nvcc_path = os.environ.get("NVCC")
    if nvcc_path:
        return Path(nvcc_path).resolve().parent.parent
    # common default
    default = Path("/usr/local/cuda")
    if default.exists():
        return default
    return None


class BuildExt(build_ext):
    def build_extensions(self):
        cuda_home = _cuda_home()
        for ext in self.extensions:
            cuda_sources = [s for s in ext.sources if s.endswith(".cu")]
            ext.sources = [s for s in ext.sources if not s.endswith(".cu")]
            objects = []
            if cuda_sources:
                if cuda_home is None:
                    raise RuntimeError("CUDA not found. Set CUDA_HOME or CUDA_PATH.")
                build_temp = Path(self.build_temp)
                build_temp.mkdir(parents=True, exist_ok=True)
                for src in cuda_sources:
                    src_path = Path(src)
                    obj_path = build_temp / (src_path.stem + ".o")
                    nvcc = str(cuda_home / "bin" / "nvcc")
                    cmd = [
                        nvcc,
                        "-c",
                        str(src_path),
                        "-o",
                        str(obj_path),
                        "-Xcompiler",
                        "-fPIC",
                        "-O3",
                        "--use_fast_math",
                        "-std=c++14",
                    ]
                    for inc in ext.include_dirs:
                        cmd.extend(["-I", inc])
                    self.spawn(cmd)
                    objects.append(str(obj_path))
            if objects:
                ext.extra_objects = (ext.extra_objects or []) + objects
        super().build_extensions()


cuda_home = _cuda_home()
include_dirs = [np.get_include()]
library_dirs = []
libraries = []

# Allow CPU-only installs when CUDA is missing.
enable_cuda = os.environ.get("TENSOR_CUDA", "auto").lower()
use_cuda = enable_cuda not in ("0", "false", "off", "no")

ext_modules = []
if use_cuda and cuda_home is not None:
    include_dirs.append(str(cuda_home / "include"))
    lib64 = cuda_home / "lib64"
    lib = cuda_home / "lib"
    if lib64.exists():
        library_dirs.append(str(lib64))
    elif lib.exists():
        library_dirs.append(str(lib))
    libraries.append("cudart")

    ext_modules = [
        Extension(
            "tensor.cuda._tensor_cuda",
            sources=[
                "cuda/bindings.cpp",
                "cuda/kernels/kernels.cu",
            ],
            include_dirs=include_dirs,
            language="c++",
            libraries=libraries,
            library_dirs=library_dirs,
            extra_compile_args=["-O3", "-std=c++14"],
        )
    ]
elif use_cuda and cuda_home is None:
    if enable_cuda in ("1", "true", "on", "yes"):
        raise RuntimeError("CUDA requested but not found. Set CUDA_HOME or CUDA_PATH.")
    print("WARNING: CUDA not found. Skipping CUDA extension build.")

setup(
    packages=find_packages("python"),
    package_dir={"": "python"},
    ext_modules=ext_modules,
    cmdclass={"build_ext": BuildExt},
)
