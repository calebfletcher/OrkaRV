


```bash
python3 -m venv venv
. venv/bin/activate

pip install git+https://github.com/riscv-non-isa/riscv-arch-test/#subdirectory=riscv-isac
pip install git+https://github.com/riscv-software-src/riscof.git
pip install git+https://github.com/riscv-software-src/riscv-config.git@dev

# check install
riscof --help


# install riscv toolchain
sudo apt-get install autoconf automake autotools-dev curl python3 libmpc-dev \
    libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool \
    patchutils bc zlib1g-dev libexpat-dev
git clone --recursive https://github.com/riscv/riscv-gnu-toolchain
git clone --recursive https://github.com/riscv/riscv-opcodes.git
cd riscv-gnu-toolchain
sudo mkdir /opt/riscv
sudo chown $USER:$USER /opt/riscv
./configure --prefix=/opt/riscv --with-arch=rv32gc --with-abi=ilp32d
make

echo 'export PATH="/opt/riscv/bin:$PATH"' >> ~/.bashrc

# Install precompiled sail-riscv binaries
# from https://github.com/riscv/sail-riscv/releases/tag/0.8

mkdir /opt/riscv/sail
cd /opt/riscv/sail
wget https://github.com/riscv/sail-riscv/releases/download/0.8/sail-riscv-Linux-x86_64.tar.gz
tar xvf sail-Linux-x86_64.tar.gz
echo 'export PATH="/opt/riscv/sail/bin:$PATH"' >> ~/.bashrc
# restart shell

riscof setup --dutname orka
echo 'PATH=/opt/riscv/sail/bin' >> config.ini
```

YAML specs are here: https://riscv-config.readthedocs.io/en/stable/yaml-specs.html

1. Go into the orka/orka_isa.yaml
2. Update the ISA to `RV32I`
3. 


```bash
riscof --verbose info arch-test --clone
riscof validateyaml --config=config.ini
riscof testlist --config=config.ini --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env
riscof run --config=config.ini --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env
riscof run --config=config.ini --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env --no-dut-run
```