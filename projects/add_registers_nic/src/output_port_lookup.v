/////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: output_port_lookup.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: output_port_lookup.v
// Project: 4-port NIC
// Description: Connects the MAC ports to the CPU DMA ports
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module output_port_lookup
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter INPUT_ARBITER_STAGE_NUM = 2,
      parameter IO_QUEUE_STAGE_NUM = `IO_QUEUE_STAGE_NUM,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter NUM_IQ_BITS = 3,
      parameter STAGE_NUM = 4,
      parameter CPU_QUEUE_NUM = 0)

   (// --- data path interface
    output     [DATA_WIDTH-1:0]           out_data,
    output     [CTRL_WIDTH-1:0]           out_ctrl,
    output reg                            out_wr,
    input                                 out_rdy,

    input  [DATA_WIDTH-1:0]               in_data,
    input  [CTRL_WIDTH-1:0]               in_ctrl,
    input                                 in_wr,
    output                                in_rdy,

    // --- Register interface
    input                                 reg_req_in,
    input                                 reg_ack_in,
    input                                 reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]      reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]     reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]        reg_src_in,

    output reg                            reg_req_out,
    output reg                            reg_ack_out,
    output reg                            reg_rd_wr_L_out,
    output reg [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output reg [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output reg [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

    // --- Misc
    input                                 clk,
    input                                 reset);

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   //--------------------- Internal Parameter-------------------------
   localparam IN_MODULE_HDRS   = 0;
   localparam IN_PACKET        = 1;

   // Register interface
   //
   localparam NUM_REGS_USED = 1;
   localparam ADDR_WIDTH = 1;

   //---------------------- Wires/Regs -------------------------------
   reg [DATA_WIDTH-1:0] in_data_modded;
   reg [15:0]           decoded_src;
   reg                  state, state_nxt;

   // Register Interface

   wire [ADDR_WIDTH-1:0]                              addr;
   wire [`OPL_REG_ADDR_WIDTH - 1:0]                reg_addr;
   wire [`UDP_REG_ADDR_WIDTH-`OPL_REG_ADDR_WIDTH - 1:0] tag_addr;

   wire                                               addr_good;
   wire                                               tag_hit;

   reg [`CPCI_NF2_DATA_WIDTH-1:0]                     reg_data;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]                     packet_count;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]                     wr_packet_count;
   reg                                                packet_inc;
   reg                                                wr_reg;



   //----------------------- Modules ---------------------------------
   small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(2))
      input_fifo
        (.din           ({in_ctrl, in_data_modded}),  // Data in
         .wr_en         (in_wr),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({out_ctrl, out_data}),
         .full          (),
         .prog_full     (),
         .nearly_full   (in_fifo_nearly_full),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //----------------------- Logic ---------------------------------

   // Register assigns
   assign addr = reg_addr_in[ADDR_WIDTH-1:0];
   assign reg_addr = reg_addr_in[`OPL_REG_ADDR_WIDTH-1:0];
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:`OPL_REG_ADDR_WIDTH];

   assign addr_good = reg_addr[`OPL_REG_ADDR_WIDTH-1:ADDR_WIDTH] == 'h0 &&
      addr < NUM_REGS_USED;
   assign tag_hit = tag_addr == `OPL_BLOCK_ADDR;

   // end register assigns

   assign in_rdy = !in_fifo_nearly_full;
   /* pkt is from the cpu if it comes in on an odd numbered port */
   assign pkt_is_from_cpu = in_data[`IOQ_SRC_PORT_POS];


   // Registers
   // Select the register data for output
   always @(*) begin

      // Defaults
      wr_reg = 0;
      wr_packet_count = 0;

      if (reset) begin
         reg_data = 'h0;
      end
      else begin
         if (!reg_rd_wr_L_in && reg_req_in && tag_hit) begin
            wr_reg = 1;
            case (addr)
               `OPL_NUM_PKTS_SEEN: begin
                  wr_packet_count = reg_data_in;
               end
            endcase
         end
         else begin
            case (addr)
               `OPL_NUM_PKTS_SEEN:        reg_data = packet_count;
            endcase // case (reg_cnt)
         end
      end
   end

   // Register I/O
   always @(posedge clk) begin
      // Never modify the address/src
      reg_rd_wr_L_out <= reg_rd_wr_L_in;
      reg_addr_out <= reg_addr_in;
      reg_src_out <= reg_src_in;

      if( reset ) begin
         reg_req_out <= 1'b0;
         reg_ack_out <= 1'b0;
         reg_data_out <= 'h0;
      end
      else begin
         if(reg_req_in && tag_hit) begin
            if(addr_good) begin
               reg_data_out <= reg_data;
            end
            else begin
               reg_data_out <= 32'hdead_beef;
            end

            // requests complete after one cycle
            reg_ack_out <= 1'b1;
         end
         else begin
            reg_ack_out <= reg_ack_in;
            reg_data_out <= reg_data_in;
         end
         reg_req_out <= reg_req_in;
      end // else: !if( reset )
   end // always @ (posedge clk)
   // end Registers

   /* Decode the source port */
   always @(*) begin
      decoded_src = 0;
      decoded_src[in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS]] = 1'b1;
   end

   /* modify the IOQ module header */
   always @(*) begin

      in_data_modded   = in_data;
      state_nxt        = state;
      packet_inc = 0;

      case(state)
         IN_MODULE_HDRS: begin
            if(in_wr && in_ctrl==IO_QUEUE_STAGE_NUM) begin
               if(pkt_is_from_cpu) begin
                  in_data_modded[`IOQ_DST_PORT_POS+15:`IOQ_DST_PORT_POS] = {1'b0, decoded_src[15:1]};
               end
               else begin
                  in_data_modded[`IOQ_DST_PORT_POS+15:`IOQ_DST_PORT_POS] = {decoded_src[14:0], 1'b0};
               end
            end
            if(in_wr && in_ctrl==0) begin
               packet_inc = 1;
               state_nxt = IN_PACKET;
            end
         end // case: IN_MODULE_HDRS

         IN_PACKET: begin
            if(in_wr && in_ctrl!=0) begin
               state_nxt = IN_MODULE_HDRS;
            end
         end
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         state <= IN_MODULE_HDRS;
         packet_count <= 0;
      end
      else begin
         if(!wr_reg)begin
            if (packet_inc) begin
               packet_count <= packet_count + 1;
            end
            else begin
               packet_count <= packet_count;
            end
         end
         else begin
            packet_count <= wr_packet_count;
         end
         state <= state_nxt;
      end
   end

   /* handle outputs */
   assign in_fifo_rd_en = out_rdy && !in_fifo_empty;
   always @(posedge clk) begin
      out_wr <= reset ? 0 : in_fifo_rd_en;
   end

endmodule
