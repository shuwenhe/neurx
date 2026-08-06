import sys 

import json 

import bz2 

import xml .etree .ElementTree as element_tree

from pathlib import Path as path


def extract_pages (xml_path ,max_pages =0 ):

    print (f"[*] Opening {xml_path }...")

    with bz2 .open (xml_path ,'rt',encoding ='utf-8')as f :

        count =0 

        for event ,elem in element_tree .iterparse (f ,events =('end',)):

            if elem .tag .endswith ('}page'):

                title_elem =elem .find ('.//{*}title')

                text_elem =elem .find ('.//{*}revision/{*}text')

                if title_elem is not None and text_elem is not None :

                    title =title_elem .text or ""

                    text =text_elem .text or ""

                    if text .strip ():

                        yield {
                        "text":f"{title }\\n\\n{text }",
                        "meta":{"source":"wikipedia","title":title }
                        }

                        count +=1 

                        if count %1000 ==0 :

                            print (f"[*] Processed {count } pages...")

                        if max_pages >0 and count >=max_pages :

                            break 

                elem .clear ()

    print (f"[*] Total extracted: {count } pages")


def main ():

    if len (sys .argv )<3 :

        print ("Usage: wiki_to_jsonl.py <input.xml.bz2> <output.jsonl> [max_pages]")

        sys .exit (1 )

    input_file =sys .argv [1 ]

    output_file =sys .argv [2 ]

    max_pages =int (sys .argv [3 ])if len (sys .argv )>3 else 0 

    path (output_file ).parent .mkdir (parents =True ,exist_ok =True )

    with open (output_file ,'w',encoding ='utf-8')as out :

        for page in extract_pages (input_file ,max_pages ):

            json .dump (page ,out ,ensure_ascii =False )

            out .write ('\\n')

    print (f"[✓] Saved to {output_file }")


if __name__ =='__main__':

    main ()
