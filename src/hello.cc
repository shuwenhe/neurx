#include <iostream>
#include <string>

/**
 * Hello World implementation for neurx-code
 */
std::string greet(const std::string& name) {
    return "Hello, " + name + "!";
}

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << "  Welcome to neurx-code Hello World!    " << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << std::endl;

    // Basic greeting
    std::cout << "Hello, World!" << std::endl;
    std::cout << std::endl;

    // Function call
    std::string message = greet("neurx-code");
    std::cout << "Message: " << message << std::endl;
    std::cout << std::endl;

    // Program info
    std::cout << "Program Information:" << std::endl;
    std::cout << "  - Arguments: " << argc << std::endl;
    std::cout << std::endl;

    std::cout << "========================================" << std::endl;
    std::cout << "  Program executed successfully!        " << std::endl;
    std::cout << "========================================" << std::endl;

    return 0;
}
