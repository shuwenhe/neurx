"""
Comprehensive test suite for convolutional and pooling layers.
Tests Conv1d, Conv2d, Conv3d, ConvTranspose2d, and all pooling layers.
"""

import pytest
import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx')

from python.tensor.nn.conv import Conv1d, Conv2d, Conv3d, ConvTranspose1d, ConvTranspose2d, ConvTranspose3d
from python.tensor.nn.pooling import (MaxPool1d, MaxPool2d, MaxPool3d, 
                                       AvgPool1d, AvgPool2d, AvgPool3d,
                                       AdaptiveMaxPool2d, AdaptiveAvgPool2d)
from python.tensor.core import Tensor


class TestConv1d:
    """Test cases for Conv1d layer."""
    
    def test_conv1d_basic(self):
        """Test basic Conv1d forward pass."""
        conv = Conv1d(in_channels=3, out_channels=16, kernel_size=3, padding=1)
        x = Tensor(np.random.randn(2, 3, 32))
        y = conv(x)
        assert y.shape == (2, 16, 32), f"Expected (2, 16, 32), got {y.shape}"
    
    def test_conv1d_with_stride(self):
        """Test Conv1d with stride."""
        conv = Conv1d(in_channels=3, out_channels=16, kernel_size=3, stride=2, padding=1)
        x = Tensor(np.random.randn(2, 3, 32))
        y = conv(x)
        assert y.shape == (2, 16, 16), f"Expected (2, 16, 16), got {y.shape}"
    
    def test_conv1d_no_padding(self):
        """Test Conv1d without padding."""
        conv = Conv1d(in_channels=3, out_channels=16, kernel_size=3, padding=0)
        x = Tensor(np.random.randn(2, 3, 32))
        y = conv(x)
        assert y.shape == (2, 16, 30), f"Expected (2, 16, 30), got {y.shape}"
    
    def test_conv1d_groups(self):
        """Test Conv1d with groups."""
        conv = Conv1d(in_channels=4, out_channels=8, kernel_size=3, groups=2, padding=1)
        x = Tensor(np.random.randn(2, 4, 32))
        y = conv(x)
        assert y.shape == (2, 8, 32), f"Expected (2, 8, 32), got {y.shape}"


class TestConv2d:
    """Test cases for Conv2d layer."""
    
    def test_conv2d_basic(self):
        """Test basic Conv2d forward pass."""
        conv = Conv2d(in_channels=3, out_channels=16, kernel_size=3, padding=1)
        x = Tensor(np.random.randn(2, 3, 32, 32))
        y = conv(x)
        assert y.shape == (2, 16, 32, 32), f"Expected (2, 16, 32, 32), got {y.shape}"
    
    def test_conv2d_with_stride(self):
        """Test Conv2d with stride."""
        conv = Conv2d(in_channels=3, out_channels=16, kernel_size=3, stride=2, padding=1)
        x = Tensor(np.random.randn(2, 3, 32, 32))
        y = conv(x)
        assert y.shape == (2, 16, 16, 16), f"Expected (2, 16, 16, 16), got {y.shape}"
    
    def test_conv2d_rectangular_kernel(self):
        """Test Conv2d with rectangular kernel."""
        conv = Conv2d(in_channels=3, out_channels=16, kernel_size=(3, 5), padding=1)
        x = Tensor(np.random.randn(2, 3, 32, 32))
        y = conv(x)
        # With kernel (3,5) and padding 1: h=(32+2-3)/1+1=32, w=(32+2-5)/1+1=30
        assert y.shape == (2, 16, 32, 30), f"Expected (2, 16, 32, 30), got {y.shape}"
    
    def test_conv2d_no_padding(self):
        """Test Conv2d without padding."""
        conv = Conv2d(in_channels=3, out_channels=16, kernel_size=3, padding=0)
        x = Tensor(np.random.randn(2, 3, 32, 32))
        y = conv(x)
        assert y.shape == (2, 16, 30, 30), f"Expected (2, 16, 30, 30), got {y.shape}"
    
    def test_conv2d_groups(self):
        """Test Conv2d with groups (grouped convolution)."""
        conv = Conv2d(in_channels=8, out_channels=16, kernel_size=3, groups=2, padding=1)
        x = Tensor(np.random.randn(2, 8, 32, 32))
        y = conv(x)
        assert y.shape == (2, 16, 32, 32), f"Expected (2, 16, 32, 32), got {y.shape}"
    
    def test_conv2d_dilation(self):
        """Test Conv2d with dilation."""
        conv = Conv2d(in_channels=3, out_channels=16, kernel_size=3, dilation=2, padding=2)
        x = Tensor(np.random.randn(2, 3, 32, 32))
        y = conv(x)
        assert y.shape == (2, 16, 32, 32), f"Expected (2, 16, 32, 32), got {y.shape}"
    
    def test_conv2d_no_bias(self):
        """Test Conv2d without bias."""
        conv = Conv2d(in_channels=3, out_channels=16, kernel_size=3, padding=1, bias=False)
        x = Tensor(np.random.randn(2, 3, 32, 32))
        y = conv(x)
        assert y.shape == (2, 16, 32, 32), f"Expected (2, 16, 32, 32), got {y.shape}"
        assert conv.bias is None, "Expected no bias"


class TestConv3d:
    """Test cases for Conv3d layer."""
    
    def test_conv3d_basic(self):
        """Test basic Conv3d forward pass."""
        conv = Conv3d(in_channels=3, out_channels=16, kernel_size=3, padding=1)
        x = Tensor(np.random.randn(2, 3, 16, 16, 16))
        y = conv(x)
        assert y.shape == (2, 16, 16, 16, 16), f"Expected (2, 16, 16, 16, 16), got {y.shape}"
    
    def test_conv3d_with_stride(self):
        """Test Conv3d with stride."""
        conv = Conv3d(in_channels=3, out_channels=16, kernel_size=3, stride=2, padding=1)
        x = Tensor(np.random.randn(2, 3, 16, 16, 16))
        y = conv(x)
        assert y.shape == (2, 16, 8, 8, 8), f"Expected (2, 16, 8, 8, 8), got {y.shape}"
    
    def test_conv3d_groups(self):
        """Test Conv3d with groups."""
        conv = Conv3d(in_channels=4, out_channels=8, kernel_size=3, groups=2, padding=1)
        x = Tensor(np.random.randn(2, 4, 16, 16, 16))
        y = conv(x)
        assert y.shape == (2, 8, 16, 16, 16), f"Expected (2, 8, 16, 16, 16), got {y.shape}"


class TestConvTranspose2d:
    """Test cases for ConvTranspose2d layer."""
    
    def test_convtranspose2d_basic(self):
        """Test basic ConvTranspose2d forward pass."""
        conv = ConvTranspose2d(in_channels=16, out_channels=3, kernel_size=3, padding=1)
        x = Tensor(np.random.randn(2, 16, 16, 16))
        y = conv(x)
        assert y.shape == (2, 3, 16, 16), f"Expected (2, 3, 16, 16), got {y.shape}"
    
    def test_convtranspose2d_with_stride(self):
        """Test ConvTranspose2d with stride for upsampling."""
        conv = ConvTranspose2d(in_channels=16, out_channels=3, kernel_size=3, stride=2, padding=1)
        x = Tensor(np.random.randn(2, 16, 16, 16))
        y = conv(x)
        # output_size = (input-1)*stride - 2*padding + kernel_size = (16-1)*2 - 2*1 + 3 = 31
        assert y.shape == (2, 3, 31, 31), f"Expected (2, 3, 31, 31), got {y.shape}"
    
    def test_convtranspose2d_output_padding(self):
        """Test ConvTranspose2d with output padding."""
        conv = ConvTranspose2d(in_channels=16, out_channels=3, kernel_size=3, 
                              stride=2, padding=1, output_padding=1)
        x = Tensor(np.random.randn(2, 16, 16, 16))
        y = conv(x)
        # output_size = (16-1)*2 - 2*1 + 3 + 1 = 32
        assert y.shape == (2, 3, 32, 32), f"Expected (2, 3, 32, 32), got {y.shape}"


class TestMaxPool2d:
    """Test cases for MaxPool2d layer."""
    
    def test_maxpool2d_basic(self):
        """Test basic MaxPool2d forward pass."""
        pool = MaxPool2d(kernel_size=2, stride=2)
        x = Tensor(np.random.randn(2, 16, 32, 32))
        y = pool(x)
        assert y.shape == (2, 16, 16, 16), f"Expected (2, 16, 16, 16), got {y.shape}"
    
    def test_maxpool2d_with_padding(self):
        """Test MaxPool2d with padding."""
        pool = MaxPool2d(kernel_size=3, stride=1, padding=1)
        x = Tensor(np.random.randn(2, 16, 32, 32))
        y = pool(x)
        assert y.shape == (2, 16, 32, 32), f"Expected (2, 16, 32, 32), got {y.shape}"
    
    def test_maxpool2d_no_stride(self):
        """Test MaxPool2d without explicit stride (should default to kernel_size)."""
        pool = MaxPool2d(kernel_size=2)
        x = Tensor(np.random.randn(2, 16, 32, 32))
        y = pool(x)
        assert y.shape == (2, 16, 16, 16), f"Expected (2, 16, 16, 16), got {y.shape}"
    
    def test_maxpool2d_rectangular_kernel(self):
        """Test MaxPool2d with rectangular kernel."""
        pool = MaxPool2d(kernel_size=(3, 5), stride=(2, 2), padding=1)
        x = Tensor(np.random.randn(2, 16, 32, 32))
        y = pool(x)
        assert y.shape[0] == 2, f"Expected batch size 2, got {y.shape[0]}"
        assert y.shape[1] == 16, f"Expected channels 16, got {y.shape[1]}"


class TestAvgPool2d:
    """Test cases for AvgPool2d layer."""
    
    def test_avgpool2d_basic(self):
        """Test basic AvgPool2d forward pass."""
        pool = AvgPool2d(kernel_size=2, stride=2)
        x = Tensor(np.ones((2, 16, 32, 32)))
        y = pool(x)
        assert y.shape == (2, 16, 16, 16), f"Expected (2, 16, 16, 16), got {y.shape}"
        assert np.allclose(y.data, 1.0), "Expected all ones after average pooling ones"
    
    def test_avgpool2d_with_padding(self):
        """Test AvgPool2d with padding."""
        pool = AvgPool2d(kernel_size=3, stride=1, padding=1)
        x = Tensor(np.random.randn(2, 16, 32, 32))
        y = pool(x)
        assert y.shape == (2, 16, 32, 32), f"Expected (2, 16, 32, 32), got {y.shape}"
    
    def test_avgpool2d_count_include_pad(self):
        """Test AvgPool2d with count_include_pad parameter."""
        x = Tensor(np.ones((1, 1, 3, 3)))
        pool_include = AvgPool2d(kernel_size=2, stride=1, padding=1, count_include_pad=True)
        pool_exclude = AvgPool2d(kernel_size=2, stride=1, padding=1, count_include_pad=False)
        
        y_include = pool_include(x)
        y_exclude = pool_exclude(x)
        
        assert y_include.shape == y_exclude.shape, "Shapes should match"


class TestAdaptiveMaxPool2d:
    """Test cases for AdaptiveMaxPool2d layer."""
    
    def test_adaptivemaxpool2d_basic(self):
        """Test basic AdaptiveMaxPool2d forward pass."""
        pool = AdaptiveMaxPool2d(output_size=1)
        x = Tensor(np.random.randn(2, 16, 32, 32))
        y = pool(x)
        assert y.shape == (2, 16, 1, 1), f"Expected (2, 16, 1, 1), got {y.shape}"
    
    def test_adaptivemaxpool2d_rectangular_output(self):
        """Test AdaptiveMaxPool2d with rectangular output size."""
        pool = AdaptiveMaxPool2d(output_size=(8, 16))
        x = Tensor(np.random.randn(2, 16, 32, 32))
        y = pool(x)
        assert y.shape == (2, 16, 8, 16), f"Expected (2, 16, 8, 16), got {y.shape}"
    
    def test_adaptivemaxpool2d_arbitrary_input(self):
        """Test AdaptiveMaxPool2d with arbitrary input size."""
        pool = AdaptiveMaxPool2d(output_size=7)
        x = Tensor(np.random.randn(2, 16, 100, 100))
        y = pool(x)
        assert y.shape == (2, 16, 7, 7), f"Expected (2, 16, 7, 7), got {y.shape}"


class TestAdaptiveAvgPool2d:
    """Test cases for AdaptiveAvgPool2d layer."""
    
    def test_adaptiveavgpool2d_basic(self):
        """Test basic AdaptiveAvgPool2d forward pass."""
        pool = AdaptiveAvgPool2d(output_size=1)
        x = Tensor(np.ones((2, 16, 32, 32)))
        y = pool(x)
        assert y.shape == (2, 16, 1, 1), f"Expected (2, 16, 1, 1), got {y.shape}"
        assert np.allclose(y.data, 1.0), "Expected all ones"
    
    def test_adaptiveavgpool2d_rectangular_output(self):
        """Test AdaptiveAvgPool2d with rectangular output size."""
        pool = AdaptiveAvgPool2d(output_size=(8, 16))
        x = Tensor(np.random.randn(2, 16, 32, 32))
        y = pool(x)
        assert y.shape == (2, 16, 8, 16), f"Expected (2, 16, 8, 16), got {y.shape}"


class TestMaxPool1d:
    """Test cases for MaxPool1d layer."""
    
    def test_maxpool1d_basic(self):
        """Test basic MaxPool1d forward pass."""
        pool = MaxPool1d(kernel_size=2, stride=2)
        x = Tensor(np.random.randn(2, 16, 32))
        y = pool(x)
        assert y.shape == (2, 16, 16), f"Expected (2, 16, 16), got {y.shape}"


class TestMaxPool3d:
    """Test cases for MaxPool3d layer."""
    
    def test_maxpool3d_basic(self):
        """Test basic MaxPool3d forward pass."""
        pool = MaxPool3d(kernel_size=2, stride=2)
        x = Tensor(np.random.randn(2, 16, 16, 16, 16))
        y = pool(x)
        assert y.shape == (2, 16, 8, 8, 8), f"Expected (2, 16, 8, 8, 8), got {y.shape}"


class TestAvgPool1d:
    """Test cases for AvgPool1d layer."""
    
    def test_avgpool1d_basic(self):
        """Test basic AvgPool1d forward pass."""
        pool = AvgPool1d(kernel_size=2, stride=2)
        x = Tensor(np.ones((2, 16, 32)))
        y = pool(x)
        assert y.shape == (2, 16, 16), f"Expected (2, 16, 16), got {y.shape}"


class TestAvgPool3d:
    """Test cases for AvgPool3d layer."""
    
    def test_avgpool3d_basic(self):
        """Test basic AvgPool3d forward pass."""
        pool = AvgPool3d(kernel_size=2, stride=2)
        x = Tensor(np.ones((2, 16, 16, 16, 16)))
        y = pool(x)
        assert y.shape == (2, 16, 8, 8, 8), f"Expected (2, 16, 8, 8, 8), got {y.shape}"


class TestConvPoolingIntegration:
    """Integration tests for Conv and Pooling layers together."""
    
    def test_conv2d_maxpool2d_pipeline(self):
        """Test Conv2d followed by MaxPool2d."""
        conv = Conv2d(in_channels=3, out_channels=16, kernel_size=3, padding=1)
        pool = MaxPool2d(kernel_size=2, stride=2)
        
        x = Tensor(np.random.randn(2, 3, 32, 32))
        y = conv(x)
        z = pool(y)
        
        assert z.shape == (2, 16, 16, 16), f"Expected (2, 16, 16, 16), got {z.shape}"
    
    def test_conv2d_avgpool2d_adaptive_pipeline(self):
        """Test Conv2d -> AvgPool2d -> AdaptiveAvgPool2d pipeline."""
        conv = Conv2d(in_channels=3, out_channels=32, kernel_size=3, padding=1)
        avgpool = AvgPool2d(kernel_size=2, stride=2)
        adaptive = AdaptiveAvgPool2d(output_size=1)
        
        x = Tensor(np.random.randn(4, 3, 64, 64))
        y = conv(x)
        z = avgpool(y)
        w = adaptive(z)
        
        assert w.shape == (4, 32, 1, 1), f"Expected (4, 32, 1, 1), got {w.shape}"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
