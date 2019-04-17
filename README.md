# OPA_TAD_Data_Generator-SUMO-Dockerized
A dockerized version of urban traffic simulator SUMO configured to produce test data for the OPA_TAD data infrastructure

Resources to create and run the [SUMO traffic simulator](https://sumo.dlr.de/wiki/Simulation_of_Urban_MObility_-_Wiki "Go to the SUMO Wiki") dockerized.

Configuration files found in folder [/config](https://github.com/PI-BO/SUMO_dockered/tree/master/config) are copied into the container, as is the script [sumo.bash](https://github.com/PI-BO/SUMO_dockered/blob/master/sumo.bash).

Build the container using the command:
>docker-compose build

Start simulation typing:
>docker-compose up
The default command runs the bash script /usr/local/share/sumo/bin/startSUMO.bash that is set up in a way to use and store data in subdirectories below the current directory.

If you want to use different parameter sets, you can modify the bash script according to your needs. The file contains several examples you can try out by switching between lines commented out.

You should be able to run an interactive session within a SUMO container using the command:
>docker run -i -t "localhost:sumo1.1.0" /bin/bash

