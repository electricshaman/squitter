defmodule Squitter.DownlinkFormat do
  use Squitter.Enum, [
    short_acas:           0,
    altitude_reply:       4,
    identity_reply:       5,
    all_call_reply:       11,
    long_acas:            16,
    ext_squitter:         17,
    tis_b:                18,
    mil_squitter:         19,
    comm_b_alt_reply:     20,
    comm_b_id_reply:      21,
    military_other:       22,
    comm_d_elm:           24
  ]
end
