import importlib .util 

import json 

import tempfile 

import unittest 

from pathlib import path 



SCRIPT =path (__file__ ).parents [1 ]/"posttrain"/"trainer"/"train_sft.py"

SPEC =importlib .util .spec_from_file_location ("train_sft",SCRIPT )

MODULE =importlib .util .module_from_spec (SPEC )

assert SPEC .loader is not None 

SPEC .loader .exec_module (MODULE )



class fake_tokenizer :

    chat_template =None 

    eos_token_id =99 


    def __call__ (self ,text ,add_special_tokens ):

        prefix =[1 ]if add_special_tokens else []

        return {"input_ids":prefix +[2 +index for index ,_ in enumerate (text .split ())]}



class fake_chat_tokenizer (fake_tokenizer ):

    chat_template ="template"


    def apply_chat_template (self ,messages ,tokenize ,add_generation_prompt ):

        ids =[10 ,11 ]

        for message in messages :

            ids .extend ([20 if message ["role"]=="user"else 30 ,len (message ["content"])])

        if add_generation_prompt :

            ids .append (30 )

        return {"input_ids":ids ,"attention_mask":[1 ]*len (ids )}



class posttrain_data_test (unittest .test_case ):

    def test_medical_record_masks_prompt (self ):

        record ={
        "question":"Which vitamin?",
        "opa":"A",
        "opb":"B12",
        "opc":"C",
        "opd":"D",
        "cop":2 ,
        "exp":"Only animal products supply it.",
        }

        example =MODULE .encode_record (fake_tokenizer (),record ,128 )

        self .assert_is_not_none (example )

        self .assert_in (99 ,example .labels )

        self .assert_greater (sum (label ==MODULE .IGNORE_INDEX for label in example .labels ),0 )

        self .assert_greater (sum (label !=MODULE .IGNORE_INDEX for label in example .labels ),1 )


    def test_pretokenized_record_preserves_response (self ):

        record ={"input_ids":list (range (10 )),"labels":[-100 ]*6 +list (range (6 ,10 ))}

        example =MODULE .encode_record (fake_tokenizer (),record ,6 )

        self .assert_equal (example .input_ids ,[4 ,5 ,6 ,7 ,8 ,9 ])

        self .assert_equal (example .labels ,[-100 ,-100 ,6 ,7 ,8 ,9 ])


    def test_chat_template_batch_encoding_is_supported (self ):

        record ={"instruction":"Question","output":"Answer"}

        example =MODULE .encode_record (fake_chat_tokenizer (),record ,128 )

        self .assert_is_not_none (example )

        self .assert_greater (sum (label ==MODULE .IGNORE_INDEX for label in example .labels ),0 )

        self .assert_greater (sum (label !=MODULE .IGNORE_INDEX for label in example .labels ),0 )


    def test_jsonl_and_json_array_are_streamed (self ):

        records =[{"input_ids":[1 ,2 ],"labels":[-100 ,2 ]},{"input_ids":[3 ,4 ],"labels":[-100 ,4 ]}]

        with tempfile .temporary_directory ()as directory :

            jsonl =path (directory )/"data.jsonl"

            jsonl .write_text ("\n".join (json .dumps (item )for item in records ),encoding ="utf-8")

            array =path (directory )/"data.json"

            array .write_text (json .dumps (records ),encoding ="utf-8")

            self .assert_equal (list (MODULE .iter_json_records (jsonl )),records )

            self .assert_equal (list (MODULE .iter_json_records (array )),records )



if __name__ =="__main__":

    unittest .main ()

