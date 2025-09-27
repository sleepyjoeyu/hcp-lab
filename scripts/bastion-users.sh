#!/bin/bash

for i in `seq 1 3`;do
  useradd user$i
  echo redhat | passwd user$i --stdin
done

echo 'PS1="\[\e[1;31;47m\][\u\W]\$ \[\e[0m\]"' >> /home/user$i/.bashrc
echo 'PS1="\[\e[1;30;47m\][\u\W]\$ \[\e[0m\]"' >> /home/user$i/.bashrc
echo 'PS1="\[\e[1;39;45m\][\u\W]\$ \[\e[0m\]"' >> /home/user$i/.bashrc
