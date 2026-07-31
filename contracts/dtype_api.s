enum DTypeCategory {
    FloatingPoint
    Integer
    Complex
    Boolean
}
enum DType {
    Float16
    BFloat16
    Float32
    Float64
    Int8
    UInt8
    Int16
    UInt16
    Int32
    UInt32
    Int64
    UInt64
    Bool
    Complex64
    Complex128
    Float8E4M3FN
    Float8E5M2
    Custom
}
interface IDType {
    name() -> string
    category() -> DTypeCategory
    size_bytes() -> i64
    is_floating_point() -> bool
    is_integer() -> bool
    is_signed() -> bool
    equals(other: DType) -> bool
}
struct dtype_promotion_rule {
    from_dtype: DType
    to_dtype: DType
    cost: i64
}
interface IDTypePromotion {
    promote(dtype1: DType, dtype2: DType) -> DType
    get_promotion_chain(from_dtype: DType, to_dtype: DType) -> []DType
    can_promote(from_dtype: DType, to_dtype: DType) -> bool
    promotion_cost(from_dtype: DType, to_dtype: DType) -> i64
}
interface IDTypeRegistry {
    register_dtype(name: string, size: i64, category: DTypeCategory) -> DType
    register_promotion_rule(rule: dtype_promotion_rule) -> void
    get_all_promotion_rules() -> []dtype_promotion_rule
}
interface IDTypeCasting {
    cast(input: tensor, target_dtype: DType) -> tensor
    is_safe_cast(from_dtype: DType, to_dtype: DType) -> bool
    cast_cost(from_dtype: DType, to_dtype: DType) -> i64
}
interface IDTypeFormatConversion {
    convert_dtype(tensor: tensor, target_dtype: DType) -> tensor
    saturate_on_cast(tensor: tensor, target_dtype: DType) -> tensor
    bitcast(tensor: tensor, target_dtype: DType) -> tensor
}
