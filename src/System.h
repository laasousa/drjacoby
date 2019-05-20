
#pragma once

#include <Rcpp.h>

#include <vector>

//------------------------------------------------
// class holding all data, parameters and functions
class System {
  
public:
  // PUBLIC OBJECTS
  
  // data
  std::vector<double> x;
  
  // model parameters
  std::vector<double> theta_init;
  std::vector<double> theta_min;
  std::vector<double> theta_max;
  std::vector<int> trans_type;
  int d;
  
  // MCMC parameters
  std::vector<int> burnin;
  int samples;
  int rungs;
  int burnin_phases;
  std::vector<bool> bw_update;
  std::vector<bool> cov_update;
  std::vector<bool> coupling_on;
  double GTI_pow;
  int chain;
  
  // misc parameters
  bool pb_markdown;
  bool silent;
  
  // PUBLIC FUNCTIONS
  
  // constructors
  System() {};
  
  // public methods
  void load(Rcpp::List args);
  
};
