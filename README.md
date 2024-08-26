### Coin Cadence

**WIP**

Coin Cadnence is a dApp that allows users to swap any 2 token pairs using Uniswap V3

### How it works

Users can interact with the contract to create a job, specifying details such as the token path for the swap, 
the receiver's address, the swap frequency, and other relevant parameters.

Once a job is created, anyone can call the swap function. When the swap function is invoked, it checks whether the 
job’s conditions are met, such as ensuring the required time has elapsed since the last swap. If all conditions are satisfied, 
the swap is executed. This means that the execution is not limited to the contract owner or the job creator, enhancing the 
decentralization of the application by allowing any participant to trigger the swap.

To incentivize participation, the address that successfully calls the swap function receives a small portion of the input token. This encourages a wide range of users to compete to run the job.

This mechanism is still in development. Future iterations will focus on refining the incentive structure and creating a server that anyone can run to compete for rewards.
