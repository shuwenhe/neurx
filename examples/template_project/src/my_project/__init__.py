"""
模板项目主模块
"""

__version__ = "1.0.0"
__author__ = "Your Name"

import neurx

# 设置 numpy 的打印选项
neurx.set_printoptions(precision=3, suppress=True)

# 导出主要组件
from . import models
from . import data

__all__ = ["models", "data", "__version__"]
