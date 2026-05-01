"""Einstein summation convention implementation."""
import numpy as np
from .neurx import Tensor


def einsum(equation: str, *operands):
    """
    Einstein summation convention for neurx operations.
    
    This function provides a way to compute many multi-dimensional,
    linear algebraic array operations using Einstein summation convention.
    
    Args:
        equation: Subscripts for Einstein summation, e.g., 'ij,jk->ik'
        *operands: Input tensors
    
    Returns:
        Tensor: Result of the Einstein summation
    
    Examples:
        >>> # Matrix multiplication
        >>> A = neurx.rand((3, 4))
        >>> B = neurx.rand((4, 5))
        >>> C = neurx.einsum('ij,jk->ik', A, B)
        
        >>> # Batch matrix multiplication
        >>> A = neurx.rand((10, 3, 4))
        >>> B = neurx.rand((10, 4, 5))
        >>> C = neurx.einsum('bij,bjk->bik', A, B)
        
        >>> # Trace of a matrix
        >>> A = neurx.rand((5, 5))
        >>> trace = neurx.einsum('ii', A)
        
        >>> # Transpose
        >>> A = neurx.rand((3, 4))
        >>> A_T = neurx.einsum('ij->ji', A)
        
        >>> # Batch dot product
        >>> A = neurx.rand((10, 3))
        >>> B = neurx.rand((10, 3))
        >>> dots = neurx.einsum('bi,bi->b', A, B)
    """
    if not operands:
        raise ValueError("At least one operand is required")
    
    # Convert all operands to numpy arrays
    np_operands = []
    tensor_operands = []
    device = "cpu"
    requires_grad = False
    
    for op in operands:
        if isinstance(op, Tensor):
            tensor_operands.append(op)
            np_operands.append(op.to_numpy())
            if op.requires_grad:
                requires_grad = True
            if op.device == "cuda":
                device = "cuda"
        else:
            np_operands.append(np.asarray(op))
    
    # Compute forward pass using numpy's einsum
    try:
        result_np = np.einsum(equation, *np_operands)
    except Exception as e:
        raise ValueError(f"Invalid einsum equation '{equation}': {e}")
    
    # Create output neurx
    out = Tensor(
        result_np,
        requires_grad=requires_grad,
        _children=tuple(tensor_operands),
        _op="einsum",
        device=device
    )
    
    # Backward pass
    def _backward():
        if not requires_grad:
            return
        
        # For gradient computation, we need to reverse the einsum operation
        # This is complex and equation-dependent, so we use a general approach
        
        # Parse the equation
        if '->' in equation:
            inputs_str, output_str = equation.split('->')
            input_specs = inputs_str.split(',')
        else:
            # Implicit output (all unique indices)
            input_specs = equation.split(',')
            # Determine output indices (simplified)
            all_indices = set()
            for spec in input_specs:
                all_indices.update(spec)
            # Remove repeated indices (they are summed)
            output_indices = []
            for idx in sorted(all_indices):
                count = sum(spec.count(idx) for spec in input_specs)
                if count == 1:
                    output_indices.append(idx)
            output_str = ''.join(output_indices)
        
        # Compute gradients for each operand
        for i, op in enumerate(tensor_operands):
            if not op.requires_grad:
                continue
            
            # Build gradient equation
            # For operand i, we need to compute: grad_op_i = einsum(grad_out, other_ops)
            
            # Create equation that computes gradient for operand i
            # General approach: for equation "ij,jk->ik" and op 0 (ij)
            # gradient equation would be "ik,jk->ij" (grad_out with op 1)
            
            try:
                # Simplified gradient computation
                # For each operand, we construct an equation that:
                # 1. Takes the output gradient
                # 2. Contracts with all other operands
                # 3. Results in the shape of the current operand
                
                other_specs = [input_specs[j] for j in range(len(input_specs)) if j != i]
                other_ops = [np_operands[j] for j in range(len(np_operands)) if j != i]
                
                # Build gradient equation
                if other_ops:
                    grad_eq_inputs = [output_str] + other_specs
                    grad_eq = ','.join(grad_eq_inputs) + '->' + input_specs[i]
                    grad_ops = [out.grad] + other_ops
                    grad_i = np.einsum(grad_eq, *grad_ops)
                else:
                    # Only one operand, gradient is just output gradient reshaped
                    grad_eq = output_str + '->' + input_specs[i]
                    grad_i = np.einsum(grad_eq, out.grad)
                
                op.grad += grad_i
                
            except Exception as e:
                # Fallback: use numerical gradient or raise error
                raise NotImplementedError(
                    f"Gradient computation for einsum equation '{equation}' "
                    f"and operand {i} failed: {e}. "
                    "This equation may not be supported yet."
                )
    
    out._backward = _backward
    return out


__all__ = ['einsum']
