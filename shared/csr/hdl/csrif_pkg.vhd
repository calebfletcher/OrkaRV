library ieee;
context ieee.ieee_std_context;

package csr_if_pkg is
    TYPE csr_access_op IS (
        OP_WRITE, -- CSRRW with rd=x0
        OP_READ, -- CSRRS/CSRRC with rs1=x0
        OP_READ_WRITE, -- CSRRW
        OP_READ_SET, -- CSRRS
        OP_READ_CLEAR, -- CSRRC
    );
end package csr_if_pkg;