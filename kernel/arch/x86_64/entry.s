package neurx.kernel.arch.x86_64











func neurx_kernel_entry() {
    
    verify_long_mode()
    
    
    
    init_uart_com1()
    
    
    uart_print("NeurX Kernel Ready\n")
    
    
    halt_cpu()
}


func verify_long_mode() {
    
    
    
    
}



func init_uart_com1() {
    
    
    
    
    
    
    
    
    
    
    
    
}


func uart_send_char(char: int) {
    
    
    
}


func uart_print(message_ptr: int) {
    
    
    
    
    
    
}



func halt_cpu() {
    
    
    
    
    
    loop {
        
    }
}
