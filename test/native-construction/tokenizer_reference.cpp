// Independent tokenizer verification only. This executable cannot generate model logits.
#include "../../src/runtime/model/bpe_tokenizer.h"
#include <iostream>
int main(int argc,char**argv) {
    if(argc!=3)return 2;
    try {
        auto tokenizer=neurx::runtime::model::bpe_tokenizer::from_directory(argv[1]);
        auto ids=tokenizer.encode(argv[2]);
        for(auto id:ids)std::cout<<id<<' ';
        std::cout<<'\n';
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n';return 1; }
}
