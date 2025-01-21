# Implementation WORK IN PROGRESS
My implementation utilized this hardware:
- Zybo Z7-20 SoC
- PMOD ACL2
- PMOD 7-Segment

Reference Manual used:
- https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual?srsltid=AfmBOormzJQS5K90xkptIxrwMcRuk-fdFZPsUoG0ebHE5dkPe11amd6z
- https://digilent.com/reference/pmod/pmodacl2/reference-manual
- https://www.analog.com/media/en/technical-documentation/data-sheets/ADXL362.pdf
- https://digilent.com/reference/_media/pmod:pmod:pmodSSD_rm.pdf

All pins and clock divider values where derived from both of these reference manuals.

## Function of This Program:
This project implements the SPI protocol to setup and receive acceleration from the accelerometer, the it displays the acceleration on a 7 segment display. We are able to select the acceleration in the X/Y/Z axis individually or the magnitude of the overall acceleration.
