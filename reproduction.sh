#!/bin/bash

(
  cd ext/ox
  ruby extconf.rb
  make clean
  find . -name "*.rbc" -exec rm {} \;
  make
)

ruby -Ilib -Iext reproduction.rb
