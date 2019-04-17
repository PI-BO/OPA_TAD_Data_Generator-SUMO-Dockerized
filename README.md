# OPA_TAD_Data_Generator-SUMO-Dockerized
A dockerized version of urban traffic simulator SUMO configured to produce test data for the OPA_TAD data infrastructure

Resources to create and run the [SUMO traffic simulator](https://sumo.dlr.de/wiki/Simulation_of_Urban_MObility_-_Wiki "Go to the SUMO Wiki") dockerized.

Configuration files found in folder [/config](https://github.com/PI-BO/SUMO_dockered/tree/master/config) are copied into the container, as is the script [sumo.bash](https://github.com/PI-BO/SUMO_dockered/blob/master/sumo.bash).

Build the container using the command:
>docker-compose build

Start simulation typing:
>docker-compose up

You can run an interactive session within the container using the command:
>docker run -t -i sumo1.1.0 /bin/bash
