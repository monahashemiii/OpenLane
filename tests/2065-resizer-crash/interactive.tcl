set ::env(DIR) [file dirname [file normalize [info script]]]
exec openroad -exit $::env(DIR)/remake_odb.tcl
exec bash -c "set -e && \
    cd $::env(DIR)/reproducible && bash run.sh"
