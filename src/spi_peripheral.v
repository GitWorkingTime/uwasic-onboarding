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
    output wire [7:0] en_reg_out_7_0_out,
    output wire [7:0] en_reg_out_15_8_out,
    output wire [7:0] en_reg_pwm_7_0_out,
    output wire [7:0] en_reg_pwm_15_8_out,
    output wire [7:0] pwm_duty_cycle_out
);

    wire clk_sig = clk;

    integer SCLK_count = 0;
    reg transaction_start;
    reg transaction_ready;
    reg transaction_processed;

    reg [7:0] en_reg_out_7_0;
    reg [7:0] en_reg_out_15_8;
    reg [7:0] en_reg_pwm_7_0;
    reg [7:0] en_reg_pwm_15_8;
    reg [7:0] pwm_duty_cycle;

    assign en_reg_out_7_0_out = en_reg_out_7_0;
    assign en_reg_out_15_8_out = en_reg_out_15_8;
    assign en_reg_pwm_7_0_out = en_reg_pwm_7_0;
    assign en_reg_pwm_15_8_out = en_reg_pwm_15_8;
    assign pwm_duty_cycle_out = pwm_duty_cycle;

    //Clock Domain Crossing data from controller
    reg nCS_sync1, nCS_sync2, nCS_sync3; //nCS_sync3 is final output
    reg COPI_sync1, COPI_sync2, COPI_sync3; // COPI_sync3 is final output
    reg SCLK_sync1, SCLK_sync2, SCLK_sync3; // SCLK_sync3 is final output
    
    reg[14:0] data_received; //Need to store the data as a vector
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            nCS_sync1 <= 1'b0;
            nCS_sync2 <= 1'b0;
            nCS_sync3 <= 1'b0;
    
            COPI_sync1 <= 1'b0;
            COPI_sync2 <= 1'b0;
            COPI_sync3 <= 1'b0;

            SCLK_sync1 <= 1'b0;
            SCLK_sync2 <= 1'b0;
            SCLK_sync3 <= 1'b0;
        end else begin
            //nCS signal
            nCS_sync1 <= nCS;
            nCS_sync2 <= nCS_sync1;
            nCS_sync3 <= nCS_sync2;

            //COPI signal
            COPI_sync1 <= COPI;
            COPI_sync2 <= COPI_sync1;
            COPI_sync3 <= COPI_sync2;

            //SCLK signal
            SCLK_sync1 <= SCLK;
            SCLK_sync2 <= SCLK_sync1;
            SCLK_sync3 <= SCLK_sync2;

            if(nCS_sync3 == 1'b0)begin
                transaction_start <= 1'b1;
            end else begin
                transaction_start <= 1'b0;
            end


        end
    end

    //Getting SCLK rising edge
    wire SCLK_posedge = !SCLK_sync2 && SCLK_sync3;

    //Gathering Data
    always @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            transaction_start <= 1'b0;
            transaction_ready <= 1'b0;
            SCLK_count <= 0;
        end else begin
            if(SCLK_posedge && transaction_start) begin //Get a SCLK clock signal + Gather data
                data_received[14 - SCLK_count] <= COPI_sync3;
                if(SCLK_count < 14)begin
                    SCLK_count <= SCLK_count + 1; //Count the signal
                end else begin
                    SCLK_count <= 0;
                    transaction_start <= 1'b0; //Finished transaction receiving
                    transaction_ready <= 1'b1; //Transaction ready for processin
                end
            end
        end
    end

    //Updating Registers
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            //Reset registers
            en_reg_out_15_8 <= 8'b0;
            en_reg_out_7_0 <= 8'b0;
            en_reg_pwm_15_8 <= 8'b0;
            en_reg_pwm_7_0 <= 8'b0;
            pwm_duty_cycle <= 8'b0;

            //Reset validations
            transaction_processed <= 1'b0;
        end else begin
            if(transaction_ready && !transaction_processed)begin
                //If the transaction is ready to be processed and has not been processed yet:
                case(data_received[14:8])
                    7'h0: en_reg_out_7_0 <= data_received[7:0];
                    7'h1: en_reg_out_15_8 <= data_received[7:0];
                    7'h2: en_reg_pwm_7_0 <= data_received[7:0];
                    7'h3: en_reg_pwm_15_8 <= data_received[7:0];
                    7'h4: pwm_duty_cycle <= data_received[7:0];
                    default: ;//Do nothing
                endcase

                transaction_processed <= 1'b1; //Transaction is finished
            end else if(transaction_processed == 1'b1)begin
                transaction_ready <= 1'b0; //Reset the ready
                transaction_processed <= 1'b0; //Reset the transaction_processed
            end
        end
    end
endmodule