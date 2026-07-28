// Data Type API - Unified type system
//
// All supported data types and promotion rules.
// DType Promotion is centralized here, NOT in Kernel.
//
// Operator -> Dispatcher -> DTypePromotion -> Kernel
//
// This ensures consistency across all kernels.

enum DTypeCategory {
    FloatingPoint
    Integer
    Complex
    Boolean
}

enum DType {
    Float16      // half precision
    BFloat16     // brain float
    Float32      // single precision
    Float64      // double precision
    
    Int8         // signed 8-bit
    UInt8        // unsigned 8-bit
    Int16        // signed 16-bit
    UInt16       // unsigned 16-bit
    Int32        // signed 32-bit
    UInt32       // unsigned 32-bit
    Int64        // signed 64-bit
    UInt64       // unsigned 64-bit
    
    Bool         // boolean
    
    Complex64    // complex with float32
    Complex128   // complex with float64
    
    Float8E4M3FN // FP8 (E4M3FN format)
    Float8E5M2   // FP8 (E5M2 format)
    
    Custom       // custom dtype
}

interface IDType {
    // Properties
    name() -> string
    category() -> DTypeCategory
    size_bytes() -> i64  // bytes per element
    is_floating_point() -> bool
    is_integer() -> bool
    is_signed() -> bool
    
    // Comparison
    equals(other: DType) -> bool
}

struct DTypePromotionRule {
    from_dtype: DType
    to_dtype: DType
    cost: i64  // lower cost = preferred
}

interface IDTypePromotion {
    // Promote two types to common type
    promote(dtype1: DType, dtype2: DType) -> DType
    
    // Get promotion chain
    get_promotion_chain(from_dtype: DType, to_dtype: DType) -> []DType
    
    // Check if promotion is allowed
    can_promote(from_dtype: DType, to_dtype: DType) -> bool
    
    // Get promotion cost (lower = cheaper)
    promotion_cost(from_dtype: DType, to_dtype: DType) -> i64
}

interface IDTypeRegistry {
    // Register custom dtype
    register_dtype(name: string, size: i64, category: DTypeCategory) -> DType
    
    // Register promotion rule
    register_promotion_rule(rule: DTypePromotionRule) -> void
    
    // Get all promotion rules
    get_all_promotion_rules() -> []DTypePromotionRule
}

interface IDTypeCasting {
    // Cast between dtypes
    cast(input: Tensor, target_dtype: DType) -> Tensor
    
    // Check if cast is safe (no precision loss)
    is_safe_cast(from_dtype: DType, to_dtype: DType) -> bool
    
    // Get cast cost (for optimization)
    cast_cost(from_dtype: DType, to_dtype: DType) -> i64
}

interface IDTypeFormatConversion {
    // Convert tensor to different dtype
    convert_dtype(tensor: Tensor, target_dtype: DType) -> Tensor
    
    // Saturate on cast (for int types)
    saturate_on_cast(tensor: Tensor, target_dtype: DType) -> Tensor
    
    // Keep bits (reinterpret, not convert)
    bitcast(tensor: Tensor, target_dtype: DType) -> Tensor
}
