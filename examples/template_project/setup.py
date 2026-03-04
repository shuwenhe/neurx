#!/usr/bin/env python
"""
模板项目 setup.py
展示如何正确依赖 neurx 框架
"""

from setuptools import setup, find_packages

setup(
    name='my-neurx-project',
    version='1.0.0',
    description='使用 NeurX 框架的深度学习项目',
    author='Your Name',
    author_email='your.email@example.com',
    
    # 发现所有子包
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    
    python_requires='>=3.10',
    
    # 主要依赖项
    install_requires=[
        'neurx>=0.2.0',  # 核心框架依赖
        'numpy>=1.22.0',
    ],
    
    # 可选依赖组
    extras_require={
        'dev': [
            'pytest>=7.0',
            'pytest-cov>=3.0',
            'black>=22.0',
            'ruff>=0.0.200',
        ],
        'viz': [
            'matplotlib>=3.5.0',
            'tensorboard>=2.10.0',
        ],
        'data': [
            'pandas>=1.3.0',
            'scikit-learn>=1.0.0',
        ],
    },
    
    # 可执行命令
    entry_points={
        'console_scripts': [
            'train-model=my_project.train:main',
            'evaluate-model=my_project.evaluate:main',
        ],
    },
    
    # 项目元信息
    url='https://github.com/yourusername/my-neurx-project',
    license='MIT',
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Programming Language :: Python :: 3.12',
        'Topic :: Scientific/Engineering :: Artificial Intelligence',
    ],
    
    include_package_data=True,
    zip_safe=False,
)
