#' Analyze a conjoint data set and correct for measurement error
#'
#' This is the internal function used to calculate and correct marginal means or average marginal component effects of a conjoint design.
#'
#' @import dplyr
#' @import rlang
#' @import estimatr
#' @importFrom MASS mvrnorm
#' @importFrom methods is
#' @importFrom methods new
#' @keywords internal
#' @param .data A \code{\link{projoint_data}} object
#' @param .qoi A \code{\link{projoint_qoi}} object. If \code{NULL}, defaults to producing all MMs and all AMCEs.
#' @param .by_var A dichotomous variable (character) used for subgroup analysis
#' @param .structure Either \code{"profile_level"} (default) or \code{"choice_level"} 
#' @param .estimand Either \code{"mm"} for marginal mean or \code{"amce"} for average marginal component effect
#' @param .se_method By default, \code{c("analytic", "simulation", "bootstrap")} description
#' @param .irr \code{NULL} (default) if IRR is to be calculated using the repeated task. Otherwise, a numerical value
#' @param .remove_ties Logical: should ties be removed before estimation? Defaults to \code{TRUE}.
#' @param .ignore_position TRUE (default) if you ignore the location of profile (left or right). Relevant only if analyzed at the choice level
#' @param .n_sims The number of simulations. Relevant only if \code{.se_method == "simulation"} 
#' @param .n_boot The number of bootstrapped samples. Relevant only if \code{.se_method == "bootstrap"}
#' @param .weights_1 the weight to estimate IRR (see \code{\link[estimatr]{lm_robust}}): \code{NULL} (default)
#' @param .clusters_1 the clusters to estimate IRR (see \code{\link[estimatr]{lm_robust}}): \code{NULL} (default)
#' @param .se_type_1 the standard error type to estimate IRR (see \code{\link[estimatr]{lm_robust}}): \code{"classical"} (default)
#' @param .weights_2 the weight to estimate MM or AMCE (see \code{\link[estimatr]{lm_robust}}): \code{NULL} (default)
#' @param .clusters_2 the clusters to estimate MM or AMCE (see \code{\link[estimatr]{lm_robust}}): \code{NULL} (default)
#' @param .se_type_2 the standard error type to estimate MM or AMCE (see \code{\link[estimatr]{lm_robust}}): \code{"classical"} (default)
#' @return A \code{\link{projoint_results}} object

projoint_diff <- function(
    .data,
    .qoi,
    .by_var,
    .structure,
    .estimand,
    .se_method,
    .irr,
    .remove_ties,
    .ignore_position,
    .n_sims,
    .n_boot,
    .weights_1,
    .clusters_1,
    .se_type_1,
    .weights_2,
    .clusters_2,
    .se_type_2
){
  
  # estimate QoIs by subgroups ----------------------------------------------
  
  subgroup1 <- .data$data %>% filter(.data[[.by_var]] == 1)
  subgroup0 <- .data$data %>% filter(.data[[.by_var]] == 0)
  
  data1 <-  projoint_data("labels" = .data$labels, "data" = subgroup1)
  data0 <-  projoint_data("labels" = .data$labels, "data" = subgroup0)
  
  out1 <- projoint_level(.data = data1,
                         .qoi,
                         .structure,
                         .estimand,
                         .se_method,
                         .irr,
                         .remove_ties,
                         .ignore_position,
                         .n_sims,
                         .n_boot,
                         .weights_1,
                         .clusters_1,
                         .se_type_1,
                         .weights_2,
                         .clusters_2,
                         .se_type_2)
  
  out0 <- projoint_level(.data = data0,
                         .qoi,
                         .structure,
                         .estimand,
                         .se_method,
                         .irr,
                         .remove_ties,
                         .ignore_position,
                         .n_sims,
                         .n_boot,
                         .weights_1,
                         .clusters_1,
                         .se_type_1,
                         .weights_2,
                         .clusters_2,
                         .se_type_2)
  
  # prepare to return the estimates -----------------------------------------
  
  estimate1 <- out1$estimates %>% 
    dplyr::select(estimand, att_level_choose,
                  "estimate_1" = estimate,
                  "se_1" = se) %>% 
    dplyr::mutate(tau = out1$tau)
  
  estimate0 <- out0$estimates %>% 
    dplyr::select(estimand, att_level_choose,
                  "estimate_0" = estimate,
                  "se_0" = se)
  
  estimates <- estimate1 %>% 
    dplyr::left_join(estimate0, by = c("estimand", "att_level_choose")) %>% 
    mutate(estimate = estimate_1 - estimate_0,
           se = sqrt(se_1^2 + se_0^2), 
           conf.low = estimate - 1.96 * se,
           conf.high = estimate + 1.96 * se) 
  
  tau <- mean(c(out1$tau, out0$tau))

  # return estimates --------------------------------------------------------
  
  if (is.null(.irr)){
    irr <- "Estimated"
  } else {
    irr <- stringr::str_c("Assumed (", .irr, ")")
  }

  if (.estimand == "mm"){
    
    if(is.null(.qoi)){
      projoint_results("estimand" = .estimand,
                       "structure" = .structure,
                       "estimates" = estimates, 
                       "se_method" = .se_method,
                       "irr" = irr,
                       "tau" = tau,
                       "remove_ties" = .remove_ties,
                       "ignore_position" = .ignore_position,
                       "attribute_of_interest" = "all",
                       "levels_of_interest" = "all",
                       "attribute_of_interest_0" = NULL,
                       "levels_of_interest_0" = NULL,
                       "attribute_of_interest_baseline" = NULL,
                       "levels_of_interest_baseline" = NULL,
                       "attribute_of_interest_0_baseline" = NULL,
                       "levels_of_interest_0_baseline" = NULL,
                       labels = .data$labels,
                       data = .data$data) %>%
        return()
    } else {
      projoint_results("estimand" = .estimand,
                       "structure" = .structure,
                       "estimates" = estimates, 
                       "se_method" = .se_method,
                       "irr" = irr,
                       "tau" = tau,
                       "remove_ties" = .remove_ties,
                       "ignore_position" = .ignore_position,
                       "attribute_of_interest" = .qoi$attribute_of_interest,
                       "levels_of_interest" = .qoi$levels_of_interest,
                       "attribute_of_interest_0" = .qoi$attribute_of_interest_0,
                       "levels_of_interest_0" = .qoi$levels_of_interest_0,
                       "attribute_of_interest_baseline" = NULL,
                       "levels_of_interest_baseline" = NULL,
                       "attribute_of_interest_0_baseline" = NULL,
                       "levels_of_interest_0_baseline" = NULL,
                       labels = .data$labels,
                       data = .data$data) %>%
        return()
    }
    
  } else {
    
    if(is.null(.qoi)){
      projoint_results("estimand" = .estimand,
                       "structure" = .structure,
                       "estimates" = estimates, 
                       "se_method" = .se_method,
                       "irr" = irr,
                       "tau" = tau,
                       "remove_ties" = .remove_ties,
                       "ignore_position" = .ignore_position,
                       "attribute_of_interest" = "all",
                       "levels_of_interest" = "all except level1",
                       "attribute_of_interest_0" = NULL,
                       "levels_of_interest_0" = NULL,
                       "attribute_of_interest_baseline" = "all",
                       "levels_of_interest_baseline" = "level1",
                       "attribute_of_interest_0_baseline" = NULL,
                       "levels_of_interest_0_baseline" = NULL,
                       labels = .data$labels,
                       data = .data$data) %>%
        return()
    } else {
      projoint_results("estimand" = .estimand,
                       "structure" = .structure,
                       "estimates" = estimates, 
                       "se_method" = .se_method,
                       "irr" = irr,
                       "tau" = tau,
                       "remove_ties" = .remove_ties,
                       "ignore_position" = .ignore_position,
                       "attribute_of_interest" = .qoi$attribute_of_interest,
                       "levels_of_interest" = .qoi$levels_of_interest,
                       "attribute_of_interest_0" = .qoi$attribute_of_interest_0,
                       "levels_of_interest_0" = .qoi$levels_of_interest_0,
                       "attribute_of_interest_baseline" = .qoi$attribute_of_interest_baseline,
                       "levels_of_interest_baseline" = .qoi$levels_of_interest_baseline,
                       "attribute_of_interest_0_baseline" = .qoi$attribute_of_interest_0_baseline,
                       "levels_of_interest_0_baseline" = .qoi$levels_of_interest_0_baseline,
                       labels = .data$labels,
                       data = .data$data) %>%
        return()
    }
    
  }
}

