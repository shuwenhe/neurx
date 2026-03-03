"""ResNet models for image classification.

Reference:
    Deep Residual Learning for Image Recognition
    Kaiming He, Xiangyu Zhang, Shaoqing Ren, Jian Sun
    https://arxiv.org/abs/1512.03385
"""
from tensor.nn import Module, ModuleList, Conv2d, BatchNorm2d, Linear, MaxPool2d
from tensor.nn.functional import relu


def conv3x3(in_planes, out_planes, stride=1, groups=1, dilation=1):
    """3x3 convolution with padding"""
    return Conv2d(
        in_planes,
        out_planes,
        kernel_size=3,
        stride=stride,
        padding=dilation,
        groups=groups,
        bias=False,
        dilation=dilation,
    )


def conv1x1(in_planes, out_planes, stride=1):
    """1x1 convolution"""
    return Conv2d(in_planes, out_planes, kernel_size=1, stride=stride, bias=False)


class BasicBlock(Module):
    """
    Basic ResNet block for ResNet-18 and ResNet-34.
    
    Structure:
        conv3x3 -> bn -> relu -> conv3x3 -> bn -> (+identity) -> relu
    """
    expansion = 1

    def __init__(
        self,
        inplanes,
        planes,
        stride=1,
        downsample=None,
        groups=1,
        base_width=64,
        dilation=1,
    ):
        super().__init__()
        if groups != 1 or base_width != 64:
            raise ValueError("BasicBlock only supports groups=1 and base_width=64")
        if dilation > 1:
            raise NotImplementedError("Dilation > 1 not supported in BasicBlock")
        
        # Both self.conv1 and self.downsample layers downsample the input when stride != 1
        self.conv1 = conv3x3(inplanes, planes, stride)
        self.bn1 = BatchNorm2d(planes)
        self.conv2 = conv3x3(planes, planes)
        self.bn2 = BatchNorm2d(planes)
        self.downsample = downsample
        self.stride = stride

    def forward(self, x):
        identity = x

        out = self.conv1(x)
        out = self.bn1(out)
        out = relu(out)

        out = self.conv2(out)
        out = self.bn2(out)

        if self.downsample is not None:
            identity = self.downsample(x)

        out = out + identity
        out = relu(out)

        return out


class Bottleneck(Module):
    """
    Bottleneck ResNet block for ResNet-50, ResNet-101, and ResNet-152.
    
    Structure:
        conv1x1 -> bn -> relu -> conv3x3 -> bn -> relu -> conv1x1 -> bn -> (+identity) -> relu
    """
    expansion = 4

    def __init__(
        self,
        inplanes,
        planes,
        stride=1,
        downsample=None,
        groups=1,
        base_width=64,
        dilation=1,
    ):
        super().__init__()
        width = int(planes * (base_width / 64.0)) * groups
        # Both self.conv2 and self.downsample layers downsample the input when stride != 1
        self.conv1 = conv1x1(inplanes, width)
        self.bn1 = BatchNorm2d(width)
        self.conv2 = conv3x3(width, width, stride, groups, dilation)
        self.bn2 = BatchNorm2d(width)
        self.conv3 = conv1x1(width, planes * self.expansion)
        self.bn3 = BatchNorm2d(planes * self.expansion)
        self.downsample = downsample
        self.stride = stride

    def forward(self, x):
        identity = x

        out = self.conv1(x)
        out = self.bn1(out)
        out = relu(out)

        out = self.conv2(out)
        out = self.bn2(out)
        out = relu(out)

        out = self.conv3(out)
        out = self.bn3(out)

        if self.downsample is not None:
            identity = self.downsample(x)

        out = out + identity
        out = relu(out)

        return out


class ResNet(Module):
    """
    ResNet backbone model.
    
    Args:
        block: Block type (BasicBlock or Bottleneck)
        layers: List of integers specifying number of blocks in each layer
        num_classes: Number of output classes (default: 1000 for ImageNet)
        zero_init_residual: Whether to zero-initialize the last BN in each residual branch
        groups: Number of groups for grouped convolution (default: 1)
        width_per_group: Base width for grouped convolution (default: 64)
    
    Example:
        >>> model = ResNet(BasicBlock, [2, 2, 2, 2], num_classes=1000)  # ResNet-18
        >>> output = model(input_tensor)  # input: (N, 3, 224, 224)
    """

    def __init__(
        self,
        block,
        layers,
        num_classes=1000,
        zero_init_residual=False,
        groups=1,
        width_per_group=64,
        replace_stride_with_dilation=None,
    ):
        super().__init__()
        
        self.inplanes = 64
        self.dilation = 1
        
        if replace_stride_with_dilation is None:
            # Each element in the tuple indicates if we should replace
            # the 2x2 stride with a dilated convolution instead
            replace_stride_with_dilation = [False, False, False]
        if len(replace_stride_with_dilation) != 3:
            raise ValueError(
                "replace_stride_with_dilation should be None "
                f"or a 3-element tuple, got {replace_stride_with_dilation}"
            )
        
        self.groups = groups
        self.base_width = width_per_group
        
        # Initial convolution layer
        self.conv1 = Conv2d(3, self.inplanes, kernel_size=7, stride=2, padding=3, bias=False)
        self.bn1 = BatchNorm2d(self.inplanes)
        self.maxpool = MaxPool2d(kernel_size=3, stride=2, padding=1)
        
        # Residual layers
        self.layer1 = self._make_layer(block, 64, layers[0])
        self.layer2 = self._make_layer(block, 128, layers[1], stride=2, dilate=replace_stride_with_dilation[0])
        self.layer3 = self._make_layer(block, 256, layers[2], stride=2, dilate=replace_stride_with_dilation[1])
        self.layer4 = self._make_layer(block, 512, layers[3], stride=2, dilate=replace_stride_with_dilation[2])
        
        # Classification head
        self.fc = Linear(512 * block.expansion, num_classes)
        
        # Initialize weights
        self._initialize_weights(zero_init_residual)

    def _make_layer(self, block, planes, blocks, stride=1, dilate=False):
        """Create a residual layer with multiple blocks."""
        downsample = None
        previous_dilation = self.dilation
        
        if dilate:
            self.dilation *= stride
            stride = 1
        
        if stride != 1 or self.inplanes != planes * block.expansion:
            # Create downsample module
            downsample = Module()
            downsample.conv = conv1x1(self.inplanes, planes * block.expansion, stride)
            downsample.bn = BatchNorm2d(planes * block.expansion)
            downsample.forward = lambda x: downsample.bn(downsample.conv(x))
        
        layers = []
        layers.append(
            block(
                self.inplanes,
                planes,
                stride,
                downsample,
                self.groups,
                self.base_width,
                previous_dilation,
            )
        )
        self.inplanes = planes * block.expansion
        
        for _ in range(1, blocks):
            layers.append(
                block(
                    self.inplanes,
                    planes,
                    groups=self.groups,
                    base_width=self.base_width,
                    dilation=self.dilation,
                )
            )
        
        return ModuleList(layers)
    
    def _initialize_weights(self, zero_init_residual):
        """Initialize model weights."""
        # Note: In a full implementation, we would initialize conv and bn layers properly
        # For now, we rely on the default initialization
        pass

    def forward(self, x):
        """
        Forward pass through ResNet.
        
        Args:
            x: Input tensor of shape (N, 3, H, W)
        
        Returns:
            Output tensor of shape (N, num_classes)
        """
        # Stem
        x = self.conv1(x)
        x = self.bn1(x)
        x = relu(x)
        x = self.maxpool(x)

        # Residual blocks
        for block in self.layer1:
            x = block(x)
        for block in self.layer2:
            x = block(x)
        for block in self.layer3:
            x = block(x)
        for block in self.layer4:
            x = block(x)

        # Global average pooling
        # Shape: (N, C, H, W) -> (N, C)
        x = x.mean(axis=(2, 3))
        
        # Classification head
        x = self.fc(x)

        return x


def resnet18(pretrained=False, num_classes=1000, **kwargs):
    """
    ResNet-18 model from "Deep Residual Learning for Image Recognition"
    
    Args:
        pretrained: If True, returns a model pre-trained on ImageNet (not yet implemented)
        num_classes: Number of output classes (default: 1000)
        **kwargs: Additional arguments for ResNet
    
    Returns:
        ResNet model
    
    Example:
        >>> model = resnet18(num_classes=10)  # For CIFAR-10
        >>> output = model(input_tensor)
    """
    model = ResNet(BasicBlock, [2, 2, 2, 2], num_classes=num_classes, **kwargs)
    
    if pretrained:
        raise NotImplementedError(
            "Pretrained weights are not yet available. "
            "You can train from scratch or load custom weights using model.load_state_dict()"
        )
    
    return model


def resnet34(pretrained=False, num_classes=1000, **kwargs):
    """
    ResNet-34 model from "Deep Residual Learning for Image Recognition"
    
    Args:
        pretrained: If True, returns a model pre-trained on ImageNet (not yet implemented)
        num_classes: Number of output classes (default: 1000)
        **kwargs: Additional arguments for ResNet
    
    Returns:
        ResNet model
    """
    model = ResNet(BasicBlock, [3, 4, 6, 3], num_classes=num_classes, **kwargs)
    
    if pretrained:
        raise NotImplementedError("Pretrained weights are not yet available")
    
    return model


def resnet50(pretrained=False, num_classes=1000, **kwargs):
    """
    ResNet-50 model from "Deep Residual Learning for Image Recognition"
    
    Args:
        pretrained: If True, returns a model pre-trained on ImageNet (not yet implemented)
        num_classes: Number of output classes (default: 1000)
        **kwargs: Additional arguments for ResNet
    
    Returns:
        ResNet model
    """
    model = ResNet(Bottleneck, [3, 4, 6, 3], num_classes=num_classes, **kwargs)
    
    if pretrained:
        raise NotImplementedError("Pretrained weights are not yet available")
    
    return model


def resnet101(pretrained=False, num_classes=1000, **kwargs):
    """
    ResNet-101 model from "Deep Residual Learning for Image Recognition"
    
    Args:
        pretrained: If True, returns a model pre-trained on ImageNet (not yet implemented)
        num_classes: Number of output classes (default: 1000)
        **kwargs: Additional arguments for ResNet
    
    Returns:
        ResNet model
    """
    model = ResNet(Bottleneck, [3, 4, 23, 3], num_classes=num_classes, **kwargs)
    
    if pretrained:
        raise NotImplementedError("Pretrained weights are not yet available")
    
    return model


def resnet152(pretrained=False, num_classes=1000, **kwargs):
    """
    ResNet-152 model from "Deep Residual Learning for Image Recognition"
    
    Args:
        pretrained: If True, returns a model pre-trained on ImageNet (not yet implemented)
        num_classes: Number of output classes (default: 1000)
        **kwargs: Additional arguments for ResNet
    
    Returns:
        ResNet model
    """
    model = ResNet(Bottleneck, [3, 8, 36, 3], num_classes=num_classes, **kwargs)
    
    if pretrained:
        raise NotImplementedError("Pretrained weights are not yet available")
    
    return model


__all__ = [
    'ResNet',
    'BasicBlock',
    'Bottleneck',
    'resnet18',
    'resnet34',
    'resnet50',
    'resnet101',
    'resnet152',
]
