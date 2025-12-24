library ieee;
context ieee.ieee_std_context;

package csrif_pkg is
  type csr_access_op is (
    OP_WRITE, -- CSRRW with rd=x0
    OP_READ, -- CSRRS/CSRRC with rs1=x0
    OP_READ_WRITE, -- CSRRW
    OP_READ_SET, -- CSRRS
    OP_READ_CLEAR -- CSRRC
  );
end package csrif_pkg;