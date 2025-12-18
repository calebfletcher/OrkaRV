LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

PACKAGE CsrPkg IS
    SUBTYPE CsrAddress IS STD_LOGIC_VECTOR(11 DOWNTO 0);

    TYPE CsrOp IS (
        OP_WRITE, -- CSRRW with rd=x0
        OP_READ, -- CSRRS/CSRRC with rs1=x0
        OP_READ_WRITE, -- CSRRW
        OP_READ_SET, -- CSRRS
        OP_READ_CLEAR, -- CSRRC
        OP_NONE
    );

END PACKAGE;