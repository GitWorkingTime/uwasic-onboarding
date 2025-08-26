/*
ui_in[0] = SCLK
ui_in[1] = nCS
ui_in[2] = COPI

uo_out[7:0] = en_reg_out[7:0]
uio_out[7:0] = en_reg_out[15:8]
uo_out[7:0] = en_reg_pwm[7:0]
uio_out[7:0] = en_reg_pwm[15:8]
*/

module spi_peripheral(
    input wire clk,
    input wire rst_n,
    input wire COPI,
    input wire SCLK,
    input wire nCS,
    output wire[7:0] en_reg_out_7_0,
    output wire[7:0] en_reg_out_15_8,
    output wire[7:0] en_reg_pwm_7_0,
    output wire[7:0] en_reg_pwm_15_8,
    output wire[7:0] pwm_duty_cycle_out
);

    reg transcation_ready;
    reg transcation_processed;
    integer SCLK_count = 0;

    reg[6:0] reg_addr;
    reg[15:0] en_out;
    reg[15:0] en_reg_pwm;
    reg[7:0] pwm_duty_cycle;
    reg[15:0] data_received;
    reg[15:0] dff1_out;
    reg[15:0] dff2_out;

    //Detecting SCLK + nCS rising edge
    reg nCS_posedge;
    reg pulse1;
    reg pulse2;
    reg pulse3;

    always@(posedge clk)begin
        pulse1 <= SCLK;
        pulse2 <= pulse1;
        pulse3 <= pulse3;
        if(pulse2 == 1'b1 & pulse3 == 1'b0)begin
            if(nCS)begin
                nCS_posedge <= 1'b1;
            end
            SCLK_count <= SCLK_count + 1;
        end else begin
            nCS_posedge <= 1'b0;
        end
    end

    //SPI processing in the clk domain
    always @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            //Reset values
            data_received <= 16'h0;
            dff1_out <= 16'h0;
            dff2_out <= 16'h0;
            transcation_ready <= 1'b0;
        end else begin
            if(nCS_posedge)begin
                transcation_ready <= 1'b1;
            end else if(transcation_processed)begin
                transcation_ready <= 1'b0;
            end

            //Getting the data
            data_received[15] <= nCS;
            dff1_out[15] <= data_received[15];
            dff2_out[15] <= data_received[15];

            data_received[15 - SCLK_count] <= COPI;
            dff1_out[15-SCLK_count] <= data_received[15-SCLK_count];
            dff2_out[15-SCLK_count] <= data_received[15-SCLK_count]; 
        end
    end

    //Updating Registers
    assign en_reg_out_7_0 = en_out[7:0];
    assign en_reg_out_15_8 = en_out[15:8];
    assign en_reg_pwm_7_0 = en_reg_pwm[7:0];
    assign en_reg_pwm_15_8 = en_reg_pwm[15:8];
    assign pwm_duty_cycle_out = pwm_duty_cycle;
    always @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            //Reset values
            en_out <= 16'h0;
            en_reg_pwm <= 16'h0;
            pwm_duty_cycle <= 8'h0;
            transcation_processed <= 1'b0;
        end else if(transcation_ready & ~transcation_processed)begin
            reg_addr <= dff2_out[14:8];
            case(reg_addr)
                7'h0: en_out[7:0] <= dff2_out[7:0];
                7'h1: en_out[15:8] <= dff2_out[7:0];
                7'h2: en_reg_pwm[7:0] <= dff2_out[7:0];
                7'h3: en_reg_pwm[15:8] <= dff2_out[7:0];
                7'h4: pwm_duty_cycle <= dff2_out[7:0];
            endcase
            transcation_processed <= 1'b1;
        end else if(~transcation_ready & transcation_processed)begin
            transcation_processed <= 1'b0;
        end
    end




endmodule