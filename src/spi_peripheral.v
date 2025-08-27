`default_nettype none
/*
ui_in[0] = SCLK
ui_in[1] = nCS
ui_in[2] = COPI

uo_out[7:0] = en_reg_out[7:0]
uio_out[7:0] = en_reg_out[15:8]
uo_out[7:0] = en_reg_pwm[7:0]
uio_out[7:0] = en_reg_pwm[15:8]
*/
`default_nettype none

module spi_peripheral(
    input wire clk, //Internal faster clock
    input wire rst_n, //Active-low
    input wire nCS,
    input wire SCLK, //External slower clock
    input wire COPI, //Serial Data
    output wire [7:0] en_reg_out_7_0,
    output wire [7:0] en_reg_out_15_8,
    output wire [7:0] en_reg_pwm_7_0,
    output wire [7:0] en_reg_pwm_15_8,
    output wire [7:0] pwm_duty_cycle
);

    integer SCLK_count;

    reg[2:0] nCS_sync;
    reg[2:0] COPI_sync;
    reg[2:0] SCLK_sync;
    reg data_start;
    reg data_ready;
    reg data_processed;
    reg[14:0] data;
    reg[7:0] temp_en_reg_out_7_0;
    reg[7:0] temp_en_reg_out_15_8;
    reg[7:0] temp_en_reg_pwm_7_0;
    reg[7:0] temp_en_reg_pwm_15_8;
    reg[7:0] temp_pwm_duty_cycle;

    wire nCS_sig;
    wire COPI_sig;
    wire SCLK_sig;
    wire nCS_negedge;
    wire nCS_posedge;
    wire SCLK_posedge;

    assign nCS_sig = nCS_sync[2];
    assign COPI_sig = COPI_sync[2];
    assign SCLK_sig = SCLK_sync[2];
    assign nCS_negedge = ~nCS_sync[1] & nCS_sync[2];
    assign nCS_posedge = nCS_sync[1] & ~nCS_sync[2];
    assign SCLK_posedge = SCLK_sync[1] & ~SCLK_sync[2];
    assign en_reg_out_7_0 = temp_en_reg_out_7_0;
    assign en_reg_out_15_8 = temp_en_reg_out_15_8;
    assign en_reg_pwm_7_0 = temp_en_reg_pwm_7_0;
    assign en_reg_pwm_15_8 = temp_en_reg_pwm_15_8;
    assign pwm_duty_cycle = temp_pwm_duty_cycle;

    //CDC
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            //Reset all the reg:
            nCS_sync <= 3'b111; // "Transaction starts on nCS falling edge" => Active-low
            COPI_sync <= 3'b000;
            SCLK_sync <= 3'b000; // "Data captured on SCLk rising edge" => Active-high
        end else begin
            //CDC:
            nCS_sync[0] <= nCS;
            nCS_sync[1] <= nCS_sync[0];
            nCS_sync[2] <= nCS_sync[1];

            COPI_sync[0] <= COPI;
            COPI_sync[1] <= COPI_sync[0];
            COPI_sync[2] <= COPI_sync[1];

            SCLK_sync[0] <= SCLK;
            SCLK_sync[1] <= SCLK_sync[0];
            SCLK_sync[2] <= SCLK_sync[1];
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            data_start <= 1'b0;
            data_ready <= 1'b0;
            data_processed <= 1'b0;
            data <= 15'b0;
            temp_en_reg_out_15_8 <= 8'b0;
            temp_en_reg_out_7_0 <= 8'b0;
            temp_en_reg_pwm_15_8 <= 8'b0;
            temp_en_reg_pwm_7_0 <= 8'b0;
            temp_pwm_duty_cycle <= 8'b0;
        end else begin
            if(data_start)begin
                if(SCLK_count < 15 && SCLK_posedge)begin
                    data[14 - SCLK_count] <= COPI_sig;
                    SCLK_count <= SCLK_count + 1;
                end else if(SCLK_count == 15 && data_ready)begin
                    SCLK_count <= 0; //Reset bit count

                    //Parse the data:
                    if(data[14:8] == 7'h0)begin
                        temp_en_reg_out_7_0 <= data[7:0];
                    end else if(data[14:8] == 7'h1)begin
                        temp_en_reg_out_15_8 <= data[7:0];
                    end else if(data[14:8] == 7'h2)begin
                        temp_en_reg_pwm_7_0 <= data[7:0];
                    end else if(data[14:8] == 7'h3)begin
                        temp_en_reg_pwm_15_8 <= data[7:0];
                    end else if(data[14:8] == 7'h4)begin
                        temp_pwm_duty_cycle <= data[7:0];
                    end

                end
            end

            if(nCS_negedge)begin
                data_start <= 1'b1;
                data_ready <= 1'b0;
            end else if(data_processed)begin
                data_start <= 1'b0;
                data_ready <= 1'b1;
            end
        end
    end

    // Update registers only after the complete transaction has finished and been validated
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_processed <= 1'b0;
        end else if (data_ready && !data_processed) begin
            // Transaction is ready and not yet processed
            // Set the processed flag
            data_processed <= 1'b1;
        end else if (!data_ready && data_processed) begin
            // Reset processed flag when ready flag is cleared
            data_processed <= 1'b0;
        end
    end

endmodule