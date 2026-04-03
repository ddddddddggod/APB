# APB
Implemented an APB slave based on one of the AMBA protocols by modifying the [I2C slave](https://github.com/ddddddddggod/I2C) that I had previously designed.
The current master and RF modules are temporary and will later be replaced by a CPU and SRAM.

*)
The PDF files include three reference document that I used for study and one document that I organized and summarized myself.
The master and RF modules will be replaced with a **CPU** and **SRAM** .

`tb_master.v` : Verifies the master module only

`tb_master_master_top.v` : Verifies master + packet + RF

`tb_apb.v` : Full testbench including the I2C module

![diagram](https://github.com/ddddddddggod/APB/apb.png)
