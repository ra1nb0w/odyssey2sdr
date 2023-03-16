//  David Fainitski N7DDC
//  for Odyssey-2 project
//  MCP3202 control
// CS/ --|_____________________________________________________________________________________________________|--------
// CLK --|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--
// DIN      1     1     CH    1  ---------------------------------
// DOUT  ---------------------------0     B11   B10    B9   B8    B7    B6    B5    B4    B3    B2    B1    B0

module ext_io_adc(clock, SCLK, nCS, MISO, MOSI, AIN1, AIN2, pk_detect_reset, pk_detect_ack);

input  wire       clock;
output reg        SCLK;
output reg        nCS;
input  wire       MISO;
output reg        MOSI;
output reg [11:0] AIN1; // 
output reg [11:0] AIN2; // 

output reg  pk_detect_ack;		// to Orion_Tx_fifo_ctl.v
input  reg  pk_detect_reset;	// from Orion_Tx_fifo_ctl.v

reg   [5:0] ADC_state = 1'd0;
reg   [3:0] bit_cnt;
reg  [12:0] temp_1;	
reg  [12:0] temp_2;
reg CH = 0;

// NOTE: this code generates the SCLK clock for the ADC
always @ (posedge clock)
begin
  case (ADC_state)
  0:
	begin
    nCS <= 1;          // set nCS high
    bit_cnt <= 4'd12;         // set bit counter
	 CH <= ~CH;
    ADC_state <= ADC_state + 1'd1;
	end
	
  1:
	begin
    nCS  <= 0;             		// select ADC
	 SCLK <= 0;
    MOSI      <= 1; // START bit
    ADC_state <= ADC_state + 1'd1;
	end
	
  2:
	begin
    SCLK      <= 1;          // SCLK high
    ADC_state <= ADC_state + 1'd1;
	end
	
  3:
	begin
    SCLK      <= 0;          // SCLK low
	 MOSI      <= 1; // SGL/DIFF bit
    ADC_state <= ADC_state + 1'd1;
	end

   4:
	begin
    SCLK      <= 1;          // SCLK high
    ADC_state <= ADC_state + 1'd1;
	end
	
  5:
	begin
    SCLK      <= 0;          // SCLK low
	 MOSI <= CH; // Channel select
    ADC_state <= ADC_state + 1'd1;
	end
	
	6:
	begin
    SCLK      <= 1;          // SCLK high
    ADC_state <= ADC_state + 1'd1;
	end
	
  7:
	begin
    SCLK      <= 0;          // SCLK low
	 MOSI <= 1; // MSBF bit
    ADC_state <= ADC_state + 1'd1;
	end
	
	 8:
	begin
    SCLK      <= 1;          // SCLK high
    ADC_state <= ADC_state + 1'd1;
	end
	
  9:
	begin
    SCLK      <= 0;          // SCLK low
    ADC_state <= ADC_state + 1'd1;
	end
	
	10:
	begin
    SCLK      <= 1;          // SCLK high
    ADC_state <= ADC_state + 1'd1;
	end
	
	11:
	begin
	 if(CH) temp_1[bit_cnt] <= MISO; else temp_2[bit_cnt] <= MISO;
    SCLK      <= 0;          // SCLK low
	 ADC_state <= ADC_state + 1'd1;
	end 
	
  12:
    if(bit_cnt == 0) 
	 begin 
	   if(CH) AIN1 <= temp_1[11:0]; else AIN2 <= temp_2[11:0];
		ADC_state <= 1'd0;
	 end	
	 else
	 begin 
	   bit_cnt <= bit_cnt - 1'd1;
      ADC_state <= 6'd10;
	 end

  default:
    ADC_state <= 0;
  endcase
end 



//
always @(posedge clock)
begin
   if(pk_detect_reset == 1'b1) pk_detect_ack <= 1;
	else pk_detect_ack <= 0;
end



endmodule 

