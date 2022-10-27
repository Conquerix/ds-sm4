from sm4 import *
import os,binascii
import codecs

key_string = binascii.b2a_hex(os.urandom(16)).decode('utf-8')
print("Key used : " + key_string)
key = SM4Key(bytes.fromhex(key_string))
file_key=open('key.txt','w')
file_key.writelines(key_string+'\n')
file_key.close()

print("Generating random text :")
text_array = []
encrypted_text_array = []
for i in range(512):
    text_array += [binascii.b2a_hex(os.urandom(4)).decode('utf-8')]

ICB = text_array[3] + text_array[2] + text_array[1] + text_array[0]
print("ICB : " + ICB)
CNT = ICB

file_output=open('ref.txt','w')
file_output_C=open('ref_C.txt','w')
file_output.writelines(text_array[0]+'\n')
file_output.writelines(text_array[1]+'\n')
file_output.writelines(text_array[2]+'\n')
file_output.writelines(text_array[3]+'\n')
file_output_C.writelines(text_array[3]+text_array[2]+text_array[1]+text_array[0]+'\n')

for n in range(1,128):
    i = 4*n
    CNT_plain_increment = binascii.unhexlify(CNT[24:32])
    CNT_plain_increment_length = len(CNT_plain_increment)
    CNT_number_increment = int.from_bytes(CNT_plain_increment, 'big')
    CNT_number_increment += 1
    new_CNT_plain_increment = CNT_number_increment.to_bytes(CNT_plain_increment_length, 'big')
    CNT_hex_increment = binascii.hexlify(new_CNT_plain_increment)
    CNT_hex_increment = codecs.decode(CNT_hex_increment, 'utf-8')
    CNT = CNT[0:24] + CNT_hex_increment[0:8]
    crypt = key.encrypt(bytes.fromhex(CNT))
    text = text_array[i+3] + text_array[i+2] + text_array[i+1] + text_array[i+0]
    text_bytes = bytes.fromhex(text)
    encrypted_text_a = [ a ^ b for (a,b) in zip(text_bytes, crypt)]
    encrypted_text = bytes(encrypted_text_a).hex()
    file_output.writelines(encrypted_text[24:32]+'\n')
    file_output.writelines(encrypted_text[16:24]+'\n')
    file_output.writelines(encrypted_text[8:16]+'\n')
    file_output.writelines(encrypted_text[0:8]+'\n')
    file_output_C.writelines(encrypted_text+'\n')
file_output.close()
file_output_C.close()

file_input_C=open('in_C.txt','w')
for i in range(len(text_array)):
    if i%4 == 0:
        file_input_C.writelines(text_array[i+3]+text_array[i+2]+text_array[i+1]+text_array[i]+'\n')
file_input_C.close()

file_input=open('in.txt','w')
for i in range(len(text_array)):
    if i%4 == 0:
        file_input.writelines(text_array[i]+'\n')
        file_input.writelines(text_array[i+1]+'\n')
        file_input.writelines(text_array[i+2]+'\n')
        file_input.writelines(text_array[i+3]+'\n')
file_input.close()

print("Done!")
