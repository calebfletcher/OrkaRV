LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

PACKAGE csrif_pkg IS
    TYPE csr_access_op IS (
        OP_WRITE, -- CSRRW with rd=x0
        OP_READ, -- CSRRS/CSRRC with rs1=x0
        OP_READ_WRITE, -- CSRRW
        OP_READ_SET, -- CSRRS
        OP_READ_CLEAR -- CSRRC
    );
END PACKAGE csrif_pkg;