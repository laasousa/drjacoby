
#------------------------------------------------
#' @title Series of standard colours used within the drjacoby package
#'   
#' @description Returns a series of standard colours used within the drjacoby
#'   package.
#' 
#' @importFrom grDevices rgb
#' @export

drjacoby_cols <- function() {
  ret <- c(rgb(159, 196, 232, maxColorValue = 255),
           rgb(78, 122, 166, maxColorValue = 255),
           rgb(202, 90, 106, maxColorValue = 255),
           rgb(195, 42, 85, maxColorValue = 255))
  return(ret)
}

#------------------------------------------------
#' @title Plot loglikelihood 95\% credible intervals
#'   
#' @description Plot loglikelihood 95\% credible intervals.
#'   
#' @param x an object of class \code{drjacoby_output}
#' @param chain which chain to plot.
#' @param phase which phase to plot. Must be either "burnin" or "sampling".
#' @param x_axis_type how to format the x-axis. 1 = integer rungs, 2 = values of
#'   the thermodynamic power.
#' @param y_axis_type how to format the y-axis. 1 = raw values, 2 = truncated at
#'   auto-chosen lower limit. 3 = double-log scale.
#'
#' @export

plot_rung_loglike <- function(x, chain = 1, phase = "sampling", x_axis_type = 1, y_axis_type = 1) {
  
  # check inputs
  assert_custom_class(x, "drjacoby_output")
  assert_single_pos_int(chain)
  assert_leq(chain, length(x))
  assert_in(phase, c("burnin", "sampling"))
  assert_single_pos_int(x_axis_type)
  assert_in(x_axis_type, 1:2)
  assert_single_pos_int(y_axis_type)
  assert_in(y_axis_type, 1:3)
  
  # declare variables to avoid "no visible binding" issues
  stage <- rung <- value <- loglikelihood <- NULL
  
  # get useful quantities
  chain_get <- paste0("chain", chain)
  beta_raised <- dplyr::filter(x$diagnostics$beta_raised, chain == chain_get) %>%
    dplyr::pull(value)
  rungs <- length(beta_raised)
  
  # define x-axis type
  if (x_axis_type == 1) {
    x_vec <- rungs:1
    x_lab <- "rung"
  } else {
    x_vec <- beta_raised
    x_lab <- "thermodynamic power"
  }
  
  # get plotting values (loglikelihoods)
  data <- dplyr::filter(x$output, chain == chain_get, stage == phase)
  y_lab <- "log-likelihood"
  
  # move to plotting deviance if specified
  if (y_axis_type == 3) {
    data$loglikelihood <- -2 * data$loglikelihood
    y_lab <- "deviance"
    
    # if needed, scale by adding/subtracting a power of ten until all values are
    # positive
    if (min(data$loglikelihood) < 0) {
      dev_scale_power <- ceiling(log(abs(min(data$loglikelihood)))/log(10))
      dev_scale_sign <- -sign(min(data$loglikelihood))
      data$loglikelihood <- data$loglikelihood + dev_scale_sign*10^dev_scale_power
      
      dev_scale_base <- ifelse(dev_scale_power == 0, 1, 10)
      dev_scale_power_char <- ifelse(dev_scale_power <= 1, "", paste("^", dev_scale_power))
      dev_scale_sign_char <- ifelse(dev_scale_sign < 0, "-", "+")
      y_lab <- parse(text = paste("deviance", dev_scale_sign_char, dev_scale_base, dev_scale_power_char))
    }
  }
  
  # get 95% credible intervals over plotting values
  y_intervals <- data %>%
    dplyr::group_by(rung) %>%
    dplyr::summarise(Q2.5 = quantile(loglikelihood, 0.025),
                     Q50 =  quantile(loglikelihood, 0.5),
                     Q97.5 = quantile(loglikelihood, 0.975))
  
  # get data into ggplot format and define temperature colours
  df <- y_intervals
  df$col <- beta_raised
  
  # produce plot
  plot1 <- ggplot(df) + theme_bw() + theme(panel.grid.minor.x = element_blank(),
                                           panel.grid.major.x = element_blank())
  plot1 <- plot1 + geom_vline(aes(xintercept = x_vec), col = grey(0.9))
  plot1 <- plot1 + geom_segment(aes_(x = ~x_vec, y = ~Q2.5, xend = ~x_vec, yend = ~Q97.5))
  plot1 <- plot1 + geom_point(aes_(x = ~x_vec, y = ~Q50, color = ~col))
  plot1 <- plot1 + xlab(x_lab) + ylab(y_lab)
  plot1 <- plot1 + scale_colour_gradientn(colours = c("red", "blue"), name = "thermodynamic\npower", limits = c(0,1))
  
  # define y-axis
  if (y_axis_type == 2) {
    y_min <- quantile(df$Q2.5, probs = 0.5)
    y_max <- max(df$Q97.5)
    plot1 <- plot1 + coord_cartesian(ylim = c(y_min, y_max))
  } else if (y_axis_type == 3) {
    plot1 <- plot1 + scale_y_continuous(trans = "log10")
  }
  
  # return plot object
  return(plot1)
}

#------------------------------------------------
#' @title Plot Metropolis coupling acceptance rates
#'
#' @description Plot Metropolis coupling acceptance rates between all rungs.
#'
#' @inheritParams plot_rung_loglike
#'
#' @import ggplot2
#' @importFrom grDevices grey
#' @export

plot_mc_acceptance <- function(x, chain = 1, phase = "sampling", x_axis_type = 1) {
  
  # check inputs
  assert_custom_class(x, "drjacoby_output")
  assert_single_pos_int(chain)
  assert_in(phase, c("burnin", "sampling"))
  assert_single_pos_int(x_axis_type)
  assert_in(x_axis_type, 1:2)
  
  # declare variables to avoid "no visible binding" issues
  stage <- value <- NULL
  
  # get useful quantities
  chain_get <- paste0("chain", chain)
  beta_raised <- dplyr::filter(x$diagnostics$beta_raised, chain == chain_get) %>%
    dplyr::pull(value)
  beta_raised_mid <- beta_raised[-1] - diff(beta_raised)/2
  rungs <- length(beta_raised)
  
  # exit if rungs = 1
  if (rungs == 1) {
    stop("no metropolis coupling when rungs = 1")
  }
  
  # define x-axis type
  if (x_axis_type == 1) {
    breaks_vec <- rungs:2
    x_vec <- (rungs:2) - 0.5
    x_lab <- "rung"
  } else {
    breaks_vec <- beta_raised
    x_vec <- beta_raised_mid
    x_lab <- "thermodynamic power"
  }
  
  # get acceptance rates
  mc_accept <- dplyr::filter(x$diagnostics$mc_accept, stage == phase, chain == chain_get) %>%
    dplyr::pull(value)
  
  # get data into ggplot format and define temperature colours
  df <- as.data.frame(mc_accept)
  df$col <- beta_raised_mid
  
  # produce plot
  plot1 <- ggplot(df) + theme_bw() + theme(panel.grid.minor.x = element_blank(),
                                           panel.grid.major.x = element_blank())
  plot1 <- plot1 + geom_vline(aes(xintercept = breaks_vec), col = grey(0.9))
  plot1 <- plot1 + scale_y_continuous(limits = c(0,1), expand = c(0,0))
  plot1 <- plot1 + geom_point(aes(x = x_vec, y = mc_accept, color = col))
  plot1 <- plot1 + xlab(x_lab) + ylab("coupling acceptance rate")
  plot1 <- plot1 + scale_colour_gradientn(colours = c("red", "blue"), name = "thermodynamic\npower", limits = c(0,1))
  
  return(plot1)
}

#------------------------------------------------
#' @title Plot autocorrelation
#'
#' @description Plot autocorrelation for specified parameters
#'
#' @inheritParams plot_rung_loglike
#' @param lag Maximum lag. Must be an integer between 20 and 500.
#' @param par Vector of parameter names. If NULL all parameters are plotted
#' @param rung Rung
#' 
#' @export

plot_autocorrelation <- function(x, lag = 20, par = NULL, chain = 1, phase = "sampling", rung = 1) {
  
  # check inputs
  assert_custom_class(x, "drjacoby_output")
  assert_single_pos_int(chain)
  assert_leq(chain, length(x))
  assert_in(phase, c("burnin", "sampling"))
  assert_single_bounded(lag, 1, 500)
  
  # declare variables to avoid "no visible binding" issues
  stage <- iteration <- loglikelihood <- NULL
  
  # get values
  chain_get <- paste0("chain", chain)
  rung_get <- paste0("rung", rung)
  data <- dplyr::filter(x$output, chain == chain_get, rung == rung_get, stage == phase) %>%
    dplyr::select(-chain, -rung, -iteration, -stage, -loglikelihood) %>%
    as.data.frame()
  
  # Select parameters
  if(!is.null(par)){
    data <- data[, colnames(data) %in% par, drop = FALSE]
  }
  
  # Estimate autocorrelation
  out <- as.data.frame(apply(data, 2, acf_data, lag = lag))
  
  # Format data for plotting
  out$lag <- 0:lag
  out <- tidyr::gather(out, "parameter", "Autocorrelation", -lag)
  
  ggplot2::ggplot(data = out,
                  ggplot2::aes(x = .data$lag, y = 0, xend = .data$lag, yend =.data$Autocorrelation)) + 
    ggplot2::geom_hline(yintercept = 0, lty = 2, col = "red") + 
    ggplot2::geom_segment(size = 1.5) +
    ggplot2::theme_bw() +
    ggplot2::ylab("Autocorrelation") +
    ggplot2::xlab("Lag") +
    ggplot2::ylim(min(0, min(out$Autocorrelation)), 1) +
    ggplot2::facet_wrap(~ parameter)
}

#------------------------------------------------
#' @title Plot parameter estimates
#'
#' @description Plot parameter estimates
#'
#' @inheritParams plot_rung_loglike
#' @param show Optional character (or vector of characters) to filter parameters by.
#'  Parameters matching show will be included.
#' @param hide Optional character (or vector of characters) to filter parameters by.
#'  Parameters matching show will be hidden.
#' @param lag Maximum lag. Must be an integer between 20 and 500
#' @param downsample Downsample chain for efficiency
#' @param display Show plots
#' @param rung Rung
#'
#' @export

plot_par <- function(x, show = NULL, hide = NULL, lag = 20,
                     downsample = TRUE, phase = "sampling", rung = 1,
                     display = TRUE) {
  
  # check inputs
  assert_custom_class(x, "drjacoby_output")
  assert_single_bounded(lag, 1, 500)
  assert_single_logical(downsample)
  assert_in(phase, c("burnin", "sampling"))
  
  # declare variables to avoid "no visible binding" issues
  stage <- chain <- NULL
  
  # get basic properties
  rung_get <- paste0("rung", rung)
  data <- dplyr::filter(x$output, rung == rung_get, stage == phase) 
  
  # choose which parameters to plot
  parameter <- setdiff(names(data), c("chain", "rung", "iteration", "stage", "logprior", "loglikelihood"))
  if(!is.null(show)){
    stopifnot(is.character(show))
    parameter <- parameter[grepl(paste(show, collapse = "|"), parameter)]
  }
  if(!is.null(hide)){
    stopifnot(is.character(hide))
    parameter <- parameter[!grepl(paste(hide, collapse = "|"), parameter)]
  }
  if(length(parameter) > 10){
    message("More than 10 parameters to summarise, consider using the show or hide arguments 
            to select parameters and reduce computation time.")
  }
  
  # Downsample
  if(downsample & nrow(data) > 2000){
    data <- data[seq.int(1, nrow(data), length.out = 2000),]
  }
  
  #chain <- NULL # to remove warning no visible binding
  data <- dplyr::group_by(data, chain)
  data <- dplyr::mutate(data, plot_par_x = 1:dplyr::n())
  data <- dplyr::ungroup(data)
  
  # Autocorrealtion (on downsample)
  ac_data <- as.data.frame(apply(data[,parameter], 2, acf_data, lag = lag))
  ac_data$lag <- 0:lag
  
  # Set minimum bin number
  b <- min(nrow(data) / 4, 40)
  
  # produce plots over all parameters
  plot_list <- c()
  for(j in 1:length(parameter)){
    pd <- data[, c("chain", "plot_par_x", parameter[j])]
    names(pd) <- c("chain", "plot_par_x", "y")
    pd2 <- ac_data[, c("lag", parameter[j])]
    names(pd2) <- c("lag", "Autocorrelation")
    
    # Histogram
    p1 <- ggplot2::ggplot(pd, ggplot2::aes(x = .data$y)) + 
      ggplot2::geom_histogram(bins = b, fill = "deepskyblue3", col = "darkblue") + 
      ggplot2::ylab("Count") + 
      ggplot2::xlab(parameter[j]) +
      ggplot2::theme_bw()
    
    # Chains
    p2 <- ggplot2::ggplot(pd, ggplot2::aes(x = .data$plot_par_x, y = .data$y, col = .data$chain)) + 
      ggplot2::geom_line() +
      scale_color_discrete(name = "Chain") +
      ggplot2::xlab("Iteration") +
      ggplot2::ylab(parameter[j]) +
      ggplot2::theme_bw()
    
    # Autocorrealtion
    p3 <- ggplot2::ggplot(data = pd2,
                          ggplot2::aes(x = .data$lag, y = 0, xend = .data$lag, yend =.data$Autocorrelation)) + 
      ggplot2::geom_hline(yintercept = 0, lty = 2, col = "red") + 
      ggplot2::geom_segment(size = 1.5) +
      ggplot2::theme_bw() +
      ggplot2::ylab("Autocorrelation") +
      ggplot2::xlab("Lag") +
      ggplot2::ylim(min(0, min(pd2$Autocorrelation)), 1)
    
    # Arrange
    pc1 <- cowplot::plot_grid(p1, p3, ncol = 2)
    pc2 <- cowplot::plot_grid(p2, pc1, nrow = 2)
    plot_list[[j]] <- list(trace = p2,
                           hist = p1,
                           acf = p3,
                           combined = pc2)
  }
  names(plot_list) <- paste0("Plot_", parameter)
  
  if(!display){
    return(invisible(plot_list))
  } else {
    # Display plots, asking user for next page if multiple parameters
    for(j in 1:length(parameter)){
      graphics::plot(plot_list[[j]]$combined)
      if(j == 1){
        default_ask <- grDevices::devAskNewPage()
        on.exit(grDevices::devAskNewPage(default_ask))
        grDevices::devAskNewPage(ask = TRUE)
      }
    }
  }
  
  return(invisible(plot_list))
}

#------------------------------------------------
#' @title Plot parameter correlation
#'
#' @description Plots correlation between two parameters
#'
#' @inheritParams plot_rung_loglike
#' @param parameter1 Name of parameter first parameter.
#' @param parameter2 Name of parameter second parameter.
#' @param downsample Downsample chain for efficiency
#' @param rung Rung
#'
#' @export

plot_cor <- function(x, parameter1, parameter2,
                     downsample = TRUE, phase = "sampling",
                     rung = 1){
  
  # check inputs
  assert_custom_class(x, "drjacoby_output")
  assert_string(parameter1)
  assert_string(parameter2)
  assert_in(parameter1, names(x$output))
  assert_in(parameter2, names(x$output))
  assert_single_logical(downsample)
  assert_in(phase, c("burnin", "sampling"))
  
  # declare variables to avoid "no visible binding" issues
  stage <- NULL
  
  # get basic quantities
  rung_get <- paste0("rung", rung)
  data <- dplyr::filter(x$output, rung == rung_get, stage == phase) 
  data <- data[,c("chain", parameter1, parameter2)]  
  colnames(data) <- c("chain", "x", "y")
  
  # Downsample
  if(downsample & nrow(data) > 2000){
    data <- data[seq.int(1, nrow(data), length.out = 2000),]
  }

  # produce plot
  ggplot2::ggplot(data = data,
                  ggplot2::aes(x = .data$x, y = .data$y, col = as.factor(.data$chain))) + 
    ggplot2::geom_point(alpha = 0.5) + 
    ggplot2::xlab(parameter1) +
    ggplot2::ylab(parameter2) +
    scale_color_discrete(name = "Chain") +
    ggplot2::theme_bw()
  
}

#------------------------------------------------
#' @title Contour plot of two parameters
#'
#' @description Produces contour plot from the posterior draws of two
#'   parameters.
#'
#' @inheritParams plot_rung_loglike
#' @param parameter1,parameter2 Name of parameters to plot.
#' @param n_levels Number of contour levels.
#' @param rung Rung
#'
#' @importFrom stats density
#' @export

plot_contour <- function(x, parameter1, parameter2, n_levels = 10, phase = "sampling", rung = 1, chain = 1) {
  
  # check inputs
  assert_custom_class(x, "drjacoby_output")
  assert_string(parameter1)
  assert_string(parameter2)
  assert_in(parameter1, names(x$output))
  assert_in(parameter2, names(x$output))
  
  # required to remove no visible binding warning
  stage <- level <- NULL
  
  # extract plotting data
  chain_get <- paste0("chain", chain)
  rung_get <- paste0("rung", rung)
  data <- dplyr::filter(x$output, rung == rung_get, stage == phase, chain == chain_get) 
  data <- data[,c(parameter1, parameter2)]  
  colnames(data) <- c("x", "y")
  
  # produce plot
  ggplot2::ggplot(data = data,
                  ggplot2::aes(x = .data$x, y = .data$y)) + 
    ggisoband::geom_density_bands(aes(fill = stat(density)), size = 0.2) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::xlab(parameter1) +
    ggplot2::ylab(parameter2) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.background = element_rect(fill = NA),
                   panel.ontop = TRUE,
                   panel.grid = element_line(colour = '#00000020')) +
    ggplot2::scale_fill_gradientn(colours = c("white", "#FEE090", "#FC8D59", "#D73027"),
                                  name = "posterior\ndensity", limits = c(0,NA))
  
}
