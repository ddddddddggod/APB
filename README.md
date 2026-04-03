# APB
Implemented an APB slave based on one of the AMBA protocols by modifying the [I2C slave](https://github.com/ddddddddggod/I2C) that I had previously designed.
The current master and RF modules are temporary and will later be replaced by a CPU and SRAM.

The master and RF modules will be replaced with a **CPU** and **SRAM** .

`tb_master.v` : Verifies the master module only

`tb_master_master_top.v` : Verifies master + packet + RF


`tb_apb.v` : Full testbench including the I2C module
