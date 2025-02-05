
## Delete resources

When we are finished with the experiment, we delete resources to free them for others.

We will use the Horizon GUI again. To access this interface,

* from the [Chameleon website](https://chameleoncloud.org/hardware/)
* click "Experiment" > "KVM@TACC"
* log in if prompted to do so
* check the project drop-down menu near the top left (which shows e.g. "CHI-XXXXXX"), and make sure the correct project is selected.

Then, delete resources in *exactly* this order:

- First, click on Network > Floating IPs. In any row that includes your net ID in the "Mapped Fixed IP Address" column, click "Disassociate", then "Release Floating IP". Wait until this is finished.
- Next, click on Compute > Instances. Check the box next to any instance(s) that include your net ID. Then, click "Delete Instances". Wait until this is finished.
- Click on Network > Networks. Check the box next to any network(s) that include your net ID. Then, click "Delete Networks". Wait until this is finished.
