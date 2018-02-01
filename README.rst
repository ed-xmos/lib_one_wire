One Wire Library
================

Summary
-------

A software library that allows you to control a one wire device.

Features
........

 * Asynchronous interface allowing client to processes other items concurrently
 * Blocking wait function provide for simple use
 * Uses single 1-bit port
 * Combinable task meaning it can share a core with other low preformance, minimally blocking tasks

Resource Usage
..............

.. resusage::

  * - configuration: |I2S| Master
    - globals:   port p_ow  = XS1_PORT_1A;
    - locals: one_wire_if i_one_wire;
    - fn: one_wire(i_one_wire, p_ow);
    - pins: 1
    - ports: 1 x (1-bit)
    - cores: 1
    - target: XCORE-200-EXPLORER

Software version and dependencies
.................................

.. libdeps::

Related application notes
.........................

The following application notes use this library:

  * See examples at https://github.com/ed-xmos/lib_one_wire/tree/master/examples/app_ds182s20
