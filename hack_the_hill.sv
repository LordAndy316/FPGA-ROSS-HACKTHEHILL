/****************************************************************************
Copyright (C) 2024 Ross Video Limited.  www.rossvideo.com

FILENAME     :  hack_the_hill.sv
PROJECT      :  Hac-A-Thon
DEVICE       :  5AGZME3H2F35C3N
DESCRIPTION  :  Top level RTL for FPGAs on IOBNC cards.

****************************************************************************/



`default_nettype none

module hack_the_hill (
   input    wire              gblrst_n_i,
   input    wire              clk_lvds_i,          // 
   input    wire              gclk0_148m50_i,      //
   input    wire              gclk1_148m50_i,      // 
   output   wire [1:0]        gclk_sel_o,
   input    wire              clkmux_in_i,         // 
   output   wire              dpaclk_sel_o,        // 
   input    wire              memrefclk_i,         // 125 MHz

   // Control System
   input    wire  [1:0]       triga_i,
   // Video
   input    wire              egress_refclk_i,
   output   wire              sdi_o,

   output   wire  [11:0]      vcxo_up_o,
   output   wire  [11:0]      vcxo_dn_o,
   output   wire  [13:0]      vcxo_fs_o,           // 1 = 148.5; 0 = 148.35

   output   wire  [5:0]       eq_cs_n_o,
   output   wire              eq_sclk_o,
   output   wire              eq_din_o,

   output   wire  [5:0]       cd_slew_o,           // 1 = SD; 0 = HD->12G
   output   wire  [5:0]       cd_mute_sclk_o,
   output   wire  [5:0]       cd_cs_n_o,
   output   wire              cd_din_o,
   // LEDs
   output   wire  [5:0]       sig_pres_o,
   output   wire  [5:0]       rx_lock_o

);

// terminate unused outputs 
//*** DO NOT MODIFY THESE !!!!!! ****
assign rx_lock_o        = 0;// Turn LED off
assign sig_pres_o       = 0;// Turn LED off
assign cd_slew_o        = 6'h00;
assign cd_mute_sclk_o   = 6'h00;
assign cd_cs_n_o        = 6'h00;
assign cd_din_o         = 1'b0;
assign eq_sclk_o        = 1'b0;
assign eq_din_o         = 1'b0;
assign eq_cs_n_o        = 6'h00;
assign gclk_sel_o       = 2'b00; // Gclock select must allways be set to zero

//////////////////////////////////////////////////////
//
// Global Power-up Reset Generator.
// On the IO card, the input pin gblrst_n_i is not asserted when the
// FPGA starts initially.
// Use the reset generator module to create a clean global asynchronous reset
// pulse of about 128 / 125MHz = 1.024 us at startup.
// The module also has a glitch filter to debounce the gblrst_n_i input pin.
// To be valid and trigger a global reset, the input pin must be asserted for
// at least 5 / 125Mhz = 40 ns.
wire gblrst, gblrst_n; // Global reset, active high and active low signals
wire  clk125_locked;
wire  clk_300m;
wire  clk_150m;
wire  clk_125m;
wire  clk_214m;
wire  rst_lvds;
wire  rst_300m;

global_reset_gen # (               // Generates a reset pulse on power-up
  .N_BIT_DEBOUNCE( 5            ), // N bit shift register debouncer (Min=2)
  .N_BIT_COUNT   ( 7            )  // 2^N pulse width counter (Min=2)
) global_reset_gen (               // 2^7 default to 128 clk_i periods
  .reset_i       (~gblrst_n_i   ), // Active high asynchronous reset input
  .clk_i         (memrefclk_i   ), // External clock oscillator
  .reset_o       (gblrst        ), // Active high global reset output
  .reset_n_o     (gblrst_n      )  // Active low  global reset output
);

clk125_pll clk125_pll (
   .reset_reset   (gblrst        ),
   .refclk_clk    (memrefclk_i   ), // 125MHz ref
   .outclk0_clk   (clk_300m      ),
   .outclk1_clk   (clk_150m      ),
   .outclk2_clk   (clk_125m      ),
   .outclk3_clk   (clk_214m      ),
   .locked_export (clk125_locked )
);

assign dpaclk_sel_o = clkmux_in_i;

// we must hold things in reset until we get a clock
reg [4:0] rst_cnt = 0;
wire      clk_rst = ~(&rst_cnt);// clock startup reset
always @(posedge clk_lvds_i) rst_cnt <= (&rst_cnt)? rst_cnt : rst_cnt + 1;//FIXME

reset_syncer reset_syncer_lvds_clk (
    .clk_i     (clk_lvds_i      ),//
    .rst_i     (gblrst | clk_rst ),//startup reset
    .rst_mh_o  (rst_lvds      ) //
);

reset_syncer reset_syncer_300m (
    .clk_i     (clk_300m    ),//
    .rst_i     (~clk125_locked),//
    .rst_mh_o  (rst_300m    ) //
);

wire            egress_tx_clkout;
wire            sdi_tx_ready    ;
wire [79:0]     sdi_tx_data     ;
wire            vid_clk         ;
wire            vid_cen         ;
wire [19:0]     vdat_bars       ;
wire [19:0]     vdat_colour     ;
wire [19:0]     vdat_tx         ;
wire [3:0]      fvht_rx         ;
wire [3:0]      fvht_tx         ;

//Ross IP
//*** DO NOT MODIFY THiS !!!!!! ****
ultrix_iob ultrix_iob(
    .clk_lvds_i         (clk_lvds_i         ),//          
    .rst_lvds_i         (rst_lvds           ),//          
    .clk_300m_i         (clk_300m           ),// 
    .rst_300m_i         (rst_300m           ),//          
    .gclk0_148m50_i     (gclk0_148m50_i     ),//
    .gclk1_148m50_i     (gclk1_148m50_i     ),// 
    .clkmux_in_i        (clkmux_in_i        ),//          
    .triga_i            (triga_i            ),//[1:0]          
    .egress_tx_clkout_i (egress_tx_clkout   ),// 
    .sdi_tx_ready_i     (sdi_tx_ready       ),//        
    .sdi_tx_data_o      (sdi_tx_data        ),//[79:0]
    .vcxo_fs_o          (vcxo_fs_o          ),//[13:0] 
    .vcxo_up_o          (vcxo_up_o          ),//[11:0] 
    .vcxo_dn_o          (vcxo_dn_o          ),//[11:0] 
    .vid_clk_o          (vid_clk            ),// 
    .vid_cen_o          (vid_cen            ),// 
    .vdat_i             (vdat_tx            ),//[19:0]
    .fvht_i             (fvht_tx            ),//[3:0]
    .vdat_bars_o        (vdat_bars          ),//[19:0]
    .vdat_colour_o      (vdat_colour        ),//[19:0]
    .fvht_o             (fvht_rx            ) //[3:0]        
);
//*****************************************************************************
wire [511:0]  RS_reg_prob;
wire [511:0]  RC_reg_prob;

probes u0 (
    .source (RC_reg_prob), //output
    .probe  (RS_reg_prob)  //input
);

always @* begin
    RS_reg_prob = RC_reg_prob;
end
//*****************************************************************************
//*****************************************************************************
///////////////////////////////////////////////////////////////////////////////
// UUT
///////////////////////////////////////////////////////////////////////////////
wire vid_sel_w = RC_reg_prob[50];
wire [29:0] sources_29 = RC_reg_prob[29:0];
wire [7:0] sources_len_1 = RC_reg_prob[37:30];
wire [7:0] sources_len_2 = RC_reg_prob[45:38];

wire [1:0] sources_mult_1 = RC_reg_prob[47:46];
wire [1:0] sources_mult_2 = RC_reg_prob[49:48];

video_uut video_uut (       
    .clk_i          (vid_clk 		),//               
    .cen_i          (vid_cen 		),//              
    .vid_sel_i      (vid_sel_w 	),//
    .probes_i  	  (sources_29   ),
    .square_length_1_i ( sources_len_1 )  ,
    .square_length_2_i ( sources_len_2 )  ,
    .speed_mult_1_i    ( sources_mult_1 )  ,   
    .speed_mult_2_i   ( sources_mult_2 ) ,
    .vdat_bars_i    (vdat_bars 	),//[19:0]
    .vdat_colour_i  (vdat_colour ),//[19:0]
    .fvht_i         (fvht_rx 		),//[ 3:0]
    .fvht_o         (fvht_tx 		),//[ 3:0]
    .video_o        (vdat_tx 		) //[19:0]
);

////*****************************************************************************
//// SDI TX PHY
////*****************************************************************************
// 40bit, ATX pll.
s5_iob_sdi_tx sdi_tx_phy (
 .pll_powerdown_pll_powerdown              (1'b0                    ),//input  [0:0] **** Has to match shared PLL ****
 .pll_select_pll_select                    (1'b0                    ),//input  [0:0]
// .reconfig_from_xcvr_reconfig_from_xcvr    (),//output [91:0]
// .reconfig_to_xcvr_reconfig_to_xcvr        (),//input  [139:0]
 .tx_10g_clkout_tx_10g_clkout              (egress_tx_clkout        ),//output [0:0]
 .tx_10g_control_tx_10g_control            (9'b0                    ),//input  [8:0]
 .tx_10g_coreclkin_tx_10g_coreclkin        (egress_tx_clkout        ),//input  [0:0]
 .tx_10g_data_valid_tx_10g_data_valid      (sdi_tx_ready            ),//input  [0:0]
 .tx_clock_clk                             (clk_125m                ),//input
 .tx_parallel_data_tx_parallel_data        (sdi_tx_data       [63:0]),//input  [63:0]
 .tx_pll_refclk_tx_pll_refclk              (egress_refclk_i         ),//input  [0:0]
 .tx_ready_tx_ready                        (sdi_tx_ready            ),//output [0:0]
// .tx_reset_reset                           (reg_sdi_tx_rst          ),//input
 .tx_reset_reset                           (1'b0                    ),//input
 .tx_serial_data_tx_serial_data            (sdi_o                   ) //output [0:0]
);

endmodule

`default_nettype wire // for bad IP that depends on this


