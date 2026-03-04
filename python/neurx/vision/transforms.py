"""Image transformations for data augmentation and preprocessing."""
import numpy as np
from neurx.neurx import Tensor

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    Image = None


class Compose:
    """
    Composes several transforms together.
    
    Args:
        transforms: List of transforms to compose
    
    Example:
        >>> transform = Compose([
        ...     Resize(256),
        ...     CenterCrop(224),
        ...     ToTensor(),
        ...     Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ... ])
    """
    def __init__(self, transforms):
        self.transforms = transforms
    
    def __call__(self, img):
        for t in self.transforms:
            img = t(img)
        return img
    
    def __repr__(self):
        format_string = self.__class__.__name__ + '('
        for t in self.transforms:
            format_string += '\n'
            format_string += f'    {t}'
        format_string += '\n)'
        return format_string


class ToTensor:
    """
    Convert a PIL Image or numpy.ndarray to neurx.
    
    Converts:
        - PIL Image (H x W x C) in range [0, 255] to Tensor (C x H x W) in range [0.0, 1.0]
        - numpy.ndarray (H x W x C) to Tensor (C x H x W)
    
    Example:
        >>> transform = ToTensor()
        >>> tensor_img = transform(pil_img)
    """
    def __call__(self, pic):
        if not HAS_PIL:
            raise ImportError("PIL is required for ToTensor. Install with: pip install Pillow")
        
        if isinstance(pic, Image.Image):
            # PIL Image -> numpy -> neurx
            mode_to_nptype = {
                'I': np.int32,
                'I;16': np.int16,
                'F': np.float32
            }
            np_img = np.array(pic, dtype=mode_to_nptype.get(pic.mode, np.uint8))
            
            # Convert to float and normalize to [0, 1]
            if np_img.dtype == np.uint8:
                np_img = np_img.astype(np.float32) / 255.0
            else:
                np_img = np_img.astype(np.float32)
                
        elif isinstance(pic, np.ndarray):
            np_img = pic.astype(np.float32)
            if np_img.max() > 1.0:
                np_img = np_img / 255.0
        else:
            raise TypeError(f"pic should be PIL Image or ndarray, got {type(pic)}")
        
        # Handle different shapes
        if np_img.ndim == 2:
            # Grayscale (H, W) -> (1, H, W)
            np_img = np_img[np.newaxis, :, :]
        elif np_img.ndim == 3:
            # RGB (H, W, C) -> (C, H, W)
            np_img = np_img.transpose((2, 0, 1))
        else:
            raise ValueError(f"pic should be 2D or 3D, got {np_img.ndim}D")
        
        return Tensor(np_img.copy())
    
    def __repr__(self):
        return self.__class__.__name__ + '()'


class Normalize:
    """
    Normalize a neurx image with mean and standard deviation.
    
    Given mean: ``(mean[1],...,mean[n])`` and std: ``(std[1],..,std[n])`` for ``n``
    channels, this transform will normalize each channel of the input neurx.
    
    Args:
        mean: Sequence of means for each channel
        std: Sequence of standard deviations for each channel
    
    Example:
        >>> # ImageNet normalization
        >>> normalize = Normalize(mean=[0.485, 0.456, 0.406],
        ...                       std=[0.229, 0.224, 0.225])
        >>> normalized_tensor = normalize(tensor_img)
    """
    def __init__(self, mean, std):
        self.mean = np.array(mean, dtype=np.float32).reshape(-1, 1, 1)
        self.std = np.array(std, dtype=np.float32).reshape(-1, 1, 1)
    
    def __call__(self, neurx):
        """
        Args:
            neurx: Tensor image of size (C, H, W) to be normalized
        
        Returns:
            Tensor: Normalized neurx image
        """
        if isinstance(neurx, Tensor):
            data = neurx.to_numpy()
            device = neurx.device
        else:
            data = np.array(neurx, dtype=np.float32)
            device = "cpu"
        
        # Normalize
        normalized = (data - self.mean) / self.std
        
        return Tensor(normalized, device=device)
    
    def __repr__(self):
        return self.__class__.__name__ + f'(mean={self.mean.flatten().tolist()}, std={self.std.flatten().tolist()})'


class Resize:
    """
    Resize the input image to the given size.
    
    Args:
        size: Desired output size. If int, smaller edge is matched to this number.
              If tuple (h, w), output size is matched to this.
        interpolation: Desired interpolation method (default: PIL.Image.BILINEAR)
    
    Example:
        >>> resize = Resize(256)
        >>> resized_img = resize(img)
        >>> # Or specify both dimensions
        >>> resize = Resize((224, 224))
    """
    def __init__(self, size, interpolation=None):
        if not HAS_PIL:
            raise ImportError("PIL is required for Resize. Install with: pip install Pillow")
        
        if isinstance(size, int):
            self.size = size
        elif isinstance(size, (tuple, list)) and len(size) == 2:
            self.size = tuple(size)
        else:
            raise ValueError(f"size should be int or (h, w) tuple, got {size}")
        
        self.interpolation = interpolation if interpolation is not None else Image.BILINEAR
    
    def __call__(self, img):
        """
        Args:
            img: PIL Image or numpy array to be resized
        
        Returns:
            PIL Image or numpy array: Resized image
        """
        if isinstance(img, Image.Image):
            if isinstance(self.size, int):
                w, h = img.size
                if (w <= h and w == self.size) or (h <= w and h == self.size):
                    return img
                if w < h:
                    ow = self.size
                    oh = int(self.size * h / w)
                else:
                    oh = self.size
                    ow = int(self.size * w / h)
                return img.resize((ow, oh), self.interpolation)
            else:
                return img.resize(self.size[::-1], self.interpolation)  # PIL uses (W, H)
                
        elif isinstance(img, np.ndarray):
            # Convert to PIL, resize, convert back
            if img.dtype == np.float32 or img.dtype == np.float64:
                pil_img = Image.fromarray((img * 255).astype(np.uint8))
            else:
                pil_img = Image.fromarray(img)
            
            resized_pil = self(pil_img)
            resized_np = np.array(resized_pil, dtype=img.dtype)
            
            if img.dtype == np.float32 or img.dtype == np.float64:
                resized_np = resized_np.astype(img.dtype) / 255.0
            
            return resized_np
        else:
            raise TypeError(f"img should be PIL Image or ndarray, got {type(img)}")
    
    def __repr__(self):
        return self.__class__.__name__ + f'(size={self.size}, interpolation={self.interpolation})'


class CenterCrop:
    """
    Crops the given image at the center.
    
    Args:
        size: Desired output size of the crop. If int, square crop is made.
    
    Example:
        >>> crop = CenterCrop(224)
        >>> cropped_img = crop(img)
    """
    def __init__(self, size):
        if isinstance(size, int):
            self.size = (size, size)
        else:
            self.size = size
    
    def __call__(self, img):
        if isinstance(img, Image.Image):
            w, h = img.size
            th, tw = self.size
            
            if w < tw or h < th:
                raise ValueError(f"Image size {(h, w)} is smaller than crop size {self.size}")
            
            i = (h - th) // 2
            j = (w - tw) // 2
            
            return img.crop((j, i, j + tw, i + th))
            
        elif isinstance(img, np.ndarray):
            if img.ndim == 2:
                h, w = img.shape
            else:
                h, w = img.shape[:2]
            
            th, tw = self.size
            
            if w < tw or h < th:
                raise ValueError(f"Image size {(h, w)} is smaller than crop size {self.size}")
            
            i = (h - th) // 2
            j = (w - tw) // 2
            
            if img.ndim == 2:
                return img[i:i+th, j:j+tw]
            else:
                return img[i:i+th, j:j+tw, :]
        else:
            raise TypeError(f"img should be PIL Image or ndarray, got {type(img)}")
    
    def __repr__(self):
        return self.__class__.__name__ + f'(size={self.size})'


class RandomCrop:
    """
    Crop the given image at a random location.
    
    Args:
        size: Desired output size of the crop. If int, square crop is made.
        padding: Optional padding on each border of the image
    
    Example:
        >>> crop = RandomCrop(224, padding=4)
        >>> cropped_img = crop(img)
    """
    def __init__(self, size, padding=None):
        if isinstance(size, int):
            self.size = (size, size)
        else:
            self.size = size
        self.padding = padding
    
    def __call__(self, img):
        if self.padding is not None:
            if isinstance(img, Image.Image):
                img = Image.fromarray(np.pad(np.array(img), 
                                            ((self.padding, self.padding), 
                                             (self.padding, self.padding), 
                                             (0, 0)), mode='constant'))
            else:
                if img.ndim == 2:
                    img = np.pad(img, self.padding, mode='constant')
                else:
                    img = np.pad(img, ((self.padding, self.padding), 
                                      (self.padding, self.padding), 
                                      (0, 0)), mode='constant')
        
        if isinstance(img, Image.Image):
            w, h = img.size
            th, tw = self.size
            
            if w < tw or h < th:
                raise ValueError(f"Image size {(h, w)} is smaller than crop size {self.size}")
            
            i = np.random.randint(0, h - th + 1)
            j = np.random.randint(0, w - tw + 1)
            
            return img.crop((j, i, j + tw, i + th))
            
        elif isinstance(img, np.ndarray):
            if img.ndim == 2:
                h, w = img.shape
            else:
                h, w = img.shape[:2]
            
            th, tw = self.size
            
            if w < tw or h < th:
                raise ValueError(f"Image size {(h, w)} is smaller than crop size {self.size}")
            
            i = np.random.randint(0, h - th + 1)
            j = np.random.randint(0, w - tw + 1)
            
            if img.ndim == 2:
                return img[i:i+th, j:j+tw]
            else:
                return img[i:i+th, j:j+tw, :]
        else:
            raise TypeError(f"img should be PIL Image or ndarray, got {type(img)}")
    
    def __repr__(self):
        return self.__class__.__name__ + f'(size={self.size}, padding={self.padding})'


class RandomHorizontalFlip:
    """
    Horizontally flip the given image randomly with a given probability.
    
    Args:
        p: Probability of the image being flipped (default: 0.5)
    
    Example:
        >>> flip = RandomHorizontalFlip(p=0.5)
        >>> flipped_img = flip(img)
    """
    def __init__(self, p=0.5):
        self.p = p
    
    def __call__(self, img):
        if np.random.random() < self.p:
            if isinstance(img, Image.Image):
                return img.transpose(Image.FLIP_LEFT_RIGHT)
            elif isinstance(img, np.ndarray):
                if img.ndim == 2:
                    return np.flip(img, axis=1).copy()
                else:
                    return np.flip(img, axis=1).copy()
            else:
                raise TypeError(f"img should be PIL Image or ndarray, got {type(img)}")
        return img
    
    def __repr__(self):
        return self.__class__.__name__ + f'(p={self.p})'


class RandomVerticalFlip:
    """
    Vertically flip the given image randomly with a given probability.
    
    Args:
        p: Probability of the image being flipped (default: 0.5)
    """
    def __init__(self, p=0.5):
        self.p = p
    
    def __call__(self, img):
        if np.random.random() < self.p:
            if isinstance(img, Image.Image):
                return img.transpose(Image.FLIP_TOP_BOTTOM)
            elif isinstance(img, np.ndarray):
                if img.ndim == 2:
                    return np.flip(img, axis=0).copy()
                else:
                    return np.flip(img, axis=0).copy()
            else:
                raise TypeError(f"img should be PIL Image or ndarray, got {type(img)}")
        return img
    
    def __repr__(self):
        return self.__class__.__name__ + f'(p={self.p})'


class ColorJitter:
    """
    Randomly change the brightness, contrast, saturation and hue of an image.
    
    Args:
        brightness: How much to jitter brightness (float or tuple)
        contrast: How much to jitter contrast (float or tuple)
        saturation: How much to jitter saturation (float or tuple)
        hue: How much to jitter hue (float or tuple)
    
    Example:
        >>> jitter = ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2, hue=0.1)
        >>> jittered_img = jitter(img)
    """
    def __init__(self, brightness=0, contrast=0, saturation=0, hue=0):
        self.brightness = self._check_input(brightness, 'brightness')
        self.contrast = self._check_input(contrast, 'contrast')
        self.saturation = self._check_input(saturation, 'saturation')
        self.hue = self._check_input(hue, 'hue', center=0, bound=(-0.5, 0.5))
    
    def _check_input(self, value, name, center=1, bound=(0, float('inf'))):
        if isinstance(value, (int, float)):
            if value < 0:
                raise ValueError(f"{name} value should be non-negative")
            value = [center - value, center + value]
            value[0] = max(value[0], bound[0])
            value[1] = min(value[1], bound[1])
        elif isinstance(value, (tuple, list)) and len(value) == 2:
            if not bound[0] <= value[0] <= value[1] <= bound[1]:
                raise ValueError(f"{name} values should be between {bound}")
        else:
            raise TypeError(f"{name} should be a single number or a list/tuple with length 2")
        return tuple(value)
    
    def __call__(self, img):
        """
        Args:
            img: PIL Image or numpy array
        
        Returns:
            PIL Image or numpy array: Color jittered image
        """
        if not HAS_PIL:
            raise ImportError("PIL is required for ColorJitter. Install with: pip install Pillow")
        
        from PIL import ImageEnhance
        
        is_numpy = isinstance(img, np.ndarray)
        if is_numpy:
            img_dtype = img.dtype
            img = Image.fromarray((img * 255).astype(np.uint8) if img.dtype in (np.float32, np.float64) else img)
        
        # Apply transforms in random order
        transforms = []
        
        if self.brightness != (1, 1):
            brightness_factor = np.random.uniform(self.brightness[0], self.brightness[1])
            transforms.append(lambda img: ImageEnhance.Brightness(img).enhance(brightness_factor))
        
        if self.contrast != (1, 1):
            contrast_factor = np.random.uniform(self.contrast[0], self.contrast[1])
            transforms.append(lambda img: ImageEnhance.Contrast(img).enhance(contrast_factor))
        
        if self.saturation != (1, 1):
            saturation_factor = np.random.uniform(self.saturation[0], self.saturation[1])
            transforms.append(lambda img: ImageEnhance.Color(img).enhance(saturation_factor))
        
        # TODO: Implement hue jittering
        
        np.random.shuffle(transforms)
        for transform in transforms:
            img = transform(img)
        
        if is_numpy:
            img = np.array(img, dtype=img_dtype)
            if img_dtype in (np.float32, np.float64):
                img = img.astype(img_dtype) / 255.0
        
        return img
    
    def __repr__(self):
        return (self.__class__.__name__ + 
                f'(brightness={self.brightness}, contrast={self.contrast}, '
                f'saturation={self.saturation}, hue={self.hue})')


__all__ = [
    'Compose',
    'ToTensor',
    'Normalize',
    'Resize',
    'CenterCrop',
    'RandomCrop',
    'RandomHorizontalFlip',
    'RandomVerticalFlip',
    'ColorJitter',
]
