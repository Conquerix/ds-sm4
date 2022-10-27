echo "### Generating text and key ###"
cd Python
python text_sample.py
cd ..
echo "### Done ###"

mkdir -p /tmp/$USER/ds-sm4/ghdl/

cp Python/in.txt /tmp/$USER/ds-sm4/ghdl/axi_memory_in.txt
cp Python/key.txt Python/ref.txt /tmp/$USER/ds-sm4/ghdl/
rm ./C/*.txt
cp Python/in_C.txt C/in.txt
cp Python/ref_C.txt C/ref.txt
cp Python/key.txt C/key.txt

echo "### Simulation ###"
make crypto_sim.sim
echo "### Done ###"

echo "### Checking diff output ###"
diff -i /tmp/$USER/ds-sm4/ghdl/ref.txt /tmp/$USER/ds-sm4/ghdl/axi_memory_out.txt
echo "### Done ###"

echo "### Checking diff input ###"
diff -i /tmp/$USER/ds-sm4/ghdl/axi_memory_in.txt /tmp/$USER/ds-sm4/ghdl/axi_memory_inb.txt
echo "### Done ###"


echo "### Viewing chronogram ###"
gtkwave /tmp/$USER/ds-sm4/ghdl/crypto_sim.ghw
echo "### Done ###"
