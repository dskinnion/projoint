#' Plot all "profile-level" MMs or AMCEs
#'
#' This method produces profile-level MM or AMCE plots given a \code{\link{projoint_results}} object, the output from the \code{\link{projoint}} function. The structure must be profile-level to use this function.
#'
#' @import ggplot2
#' @import ggthemes
#' @import dplyr
#' @import stringr
#' @keywords internal
#' @param x A \code{\link{projoint_results}} object
#' @param .estimates The estimates to be plotted, either \code{"corrected"} (default), \code{"uncorrected"}, or \code{"both"}
#' @param .by_var \code{TRUE} to plot the difference in estimates between the two subgroups, \code{FALSE} (default) otherwise 
#' @param .base_size base font size, given in pts.
#' @param .base_family base font family
#' @param ... Additional optional arguments
#' @return A \code{ggplot} object

plot_projoint_profile_level <- function(
    x, 
    .estimates = "corrected",
    .by_var = FALSE,
    .base_size = 12,
    .base_family = "",
    ...
){
  
  # check -------------------------------------------------------------------
  
  if(!is(x, "projoint_results")){
    stop("The x argument must be of class `projoint_results` from the `projoint` function.")
  }
  
  .estimand = x$estimand
  
  if (.by_var == FALSE){
    
    if (.estimand == "mm"){
      
      .xintercept = 0.5
      .xlabel = "Marginal Mean"
      
    } else if (.estimand == "amce"){
      
      .xintercept = 0
      .xlabel = "Average Marginal Component Effect"
      
    } else{
      
      stop("The .estimand argument should be either mm or amce.")
      
    }
    
  } else if (.by_var == TRUE){
    
    .xintercept = 0
    .xlabel = "Difference"
    
  } else {
    
    stop("The .by_var argument should be logical.")
    
  }
  
  
  
  # initial data wrangling --------------------------------------------------
  
  out1 <- dplyr::left_join(
    x$estimates |> 
      dplyr::mutate(level_id = att_level_choose,
                    estimates = case_when(str_detect(estimand, "uncorrected") ~ "uncorrected",
                                          str_detect(estimand, "corrected") ~ "corrected")) |>
      dplyr::select(-estimand),
    x$labels |> 
      dplyr::select(attribute, level, level_id),
    by = join_by(level_id)
  )
  
  attributes <-  x$labels |> 
    dplyr::select(attribute, level_id) |>
    dplyr::mutate(level_id = str_replace_all(level_id, "\\d+$", "0")) |> 
    dplyr::distinct()
  
  if (.estimand == "mm"){
    
    out2 <- bind_rows(
      out1,
      attributes |> dplyr::mutate(estimates = "corrected"),
      attributes |> dplyr::mutate(estimates = "uncorrected")
    ) 
    
  } else if (.estimand == "amce"){
    
    levels1 <- x$labels |> 
      dplyr::select(attribute, level, level_id) |> 
      dplyr::filter(str_detect(level_id, "level1$"))
    
    out2 <- bind_rows(
      out1,
      levels1 |> dplyr::mutate(estimates = "corrected"),
      levels1 |> dplyr::mutate(estimates = "uncorrected"),
      attributes |> dplyr::mutate(estimates = "corrected"),
      attributes |> dplyr::mutate(estimates = "uncorrected")
    ) |> 
      dplyr::arrange(level_id) |> 
      dplyr::mutate(estimate = ifelse(stringr::str_detect(level_id, "level1$"), 0, estimate),
                    se = ifelse(stringr::str_detect(level_id, "level1$"), 0, se)) 
    
    
  } 
  
  out3 <- dplyr::bind_rows(
    out2 |> 
      dplyr::filter(estimates == "corrected") |> 
      dplyr::arrange(desc(level_id)) |> 
      dplyr::mutate(order = row_number()),
    out2 |> 
      dplyr::filter(estimates == "uncorrected") |> 
      dplyr::arrange(desc(level_id)) |> 
      dplyr::mutate(order = row_number())
  )
  
  if (.estimates == "both"){
    
    out4 <- out3
    
  } else if (.estimates != "both"){
    
    out4 <- out3 |> dplyr::filter(estimates == .estimates)
    
  } else{
    
    stop("The .estimates argument should be corrected, uncorrected, or both.")
    
  }
  
  # make labels for the vertical axis ---------------------------------------
  
  labels <- out4 |> 
    dplyr::mutate(att_level_labels = ifelse(is.na(level), 
                                            stringr::str_c(attribute, ":"), 
                                            stringr::str_c("     ", level))) |> 
    dplyr::select(order, att_level_labels) |> 
    dplyr::distinct() |> 
    pull(att_level_labels)
  
  # make a figure -----------------------------------------------------------
  
  g <- ggplot2::ggplot(out4) +
    ggplot2::geom_vline(xintercept = .xintercept,
                        linetype = "dashed", 
                        color = "gray") +
    ggplot2::scale_y_continuous(breaks = 1:length(labels),
                                labels = labels) +
    ggplot2::labs(y = NULL,
                  x = .xlabel) +
    ggthemes::theme_few(base_size = .base_size, 
                        base_family = .base_family) %+replace%
    ggplot2::theme(axis.text.x =  ggplot2::element_text(size = .base_size, 
                                                        color = "black", 
                                                        hjust = .5 , 
                                                        vjust = 1),
                   axis.text.y =  ggplot2::element_text(size = .base_size, 
                                                        color = "black", 
                                                        hjust = 0  , 
                                                        vjust = 0.5),
                   axis.ticks =   ggplot2::element_line(colour = "grey50"),
                   axis.title.y = ggplot2::element_text(size = .base_size, 
                                                        angle = 90, 
                                                        vjust = .01, 
                                                        hjust = .1))
  
  
  if (.estimates != "both"){
    
    if (.estimand == "mm"){
      
      g + ggplot2::geom_pointrange(aes(x = estimate,
                                       xmin = conf.low,
                                       xmax = conf.high, 
                                       y = order), 
                                   na.rm = TRUE)
      
    } else if (.estimand == "amce"){
      
      g + ggplot2::geom_pointrange(data = out4 |> 
                                     dplyr::filter(!stringr::str_detect(level_id, "level1$")),
                                   aes(x = estimate,
                                       xmin = conf.low,
                                       xmax = conf.high, 
                                       y = order), 
                                   na.rm = TRUE) +
        ggplot2::geom_pointrange(data = out4 |> 
                                   dplyr::filter(stringr::str_detect(level_id, "level1$")),
                                 aes(x = estimate,
                                     xmin = estimate,
                                     xmax = estimate,
                                     y = order), 
                                 color = "gray",
                                 shape = 1) 
    }
    
    
  } else{
    
    if (.estimand == "mm"){
      
      g + ggplot2::geom_pointrange(data = out4,
                                   aes(x = estimate,
                                       xmin = conf.low,
                                       xmax = conf.high, 
                                       y = order,
                                       color = estimates), 
                                   position = ggplot2::position_dodge(width = 0.5),
                                   na.rm = TRUE) +
        ggplot2::theme(legend.position = "top") +
        ggplot2::labs(color = NULL)
      
    } else if (.estimand == "amce"){
      
      g + ggplot2::geom_pointrange(data = out4 |> 
                                     dplyr::filter(!stringr::str_detect(level_id, "level1$")),
                                   aes(x = estimate,
                                       xmin = conf.low,
                                       xmax = conf.high, 
                                       y = order,
                                       color = estimates), 
                                   position = ggplot2::position_dodge(width = 0.5),
                                   na.rm = TRUE) +
        ggplot2::geom_pointrange(data = out4 |> 
                                   dplyr::filter(stringr::str_detect(level_id, "level1$")),
                                 aes(x = estimate,
                                     xmin = estimate,
                                     xmax = estimate,
                                     y = order), 
                                 color = "gray",
                                 shape = 1) +
        ggplot2::theme(legend.position = "top") +
        ggplot2::labs(color = NULL)
      
      
    }
    
    
  }
  
  
}
