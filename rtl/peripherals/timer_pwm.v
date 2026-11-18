// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    timer_pwm.v
// Description: 32-Bit Prescaled Hardware Timer with Auto-Reload & 8-Bit PWM Output
// =============================================================================

`timescale 1ns / 1ps
`include "bus_defines.vh"

module timer_pwm (
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave Interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [3:0]  paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,

    // Hardware Outputs
    output reg         timer_irq,
    output wire        pwm_out
);

    assign pready = 1'b1;

    reg [31:0] timer_ctrl;      // [0]: enable, [1]: auto-reload, [2]: irq_en
    reg [31:0] timer_prescale;
    reg [31:0] timer_load;
    reg [31:0] timer_value;
    reg [7:0]  pwm_cmp;
    reg [7:0]  pwm_counter;
    reg [31:0] prescale_counter;

    // PWM Generator (8-bit)
    assign pwm_out = (pwm_counter < pwm_cmp);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= 8'd0;
        end else if (timer_ctrl[0]) begin
            pwm_counter <= pwm_counter + 1'b1;
        end
    end

    // Timer Counting Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_value      <= 32'd0;
            prescale_counter <= 32'd0;
            timer_irq        <= 1'b0;
        end else begin
            timer_irq <= 1'b0;
            if (timer_ctrl[0]) begin // Timer Enabled
                if (prescale_counter >= timer_prescale) begin
                    prescale_counter <= 32'd0;
                    if (timer_value == 32'd0) begin
                        if (timer_ctrl[2]) timer_irq <= 1'b1; // Trigger IRQ
                        if (timer_ctrl[1]) timer_value <= timer_load; // Auto-reload
                        else timer_ctrl[0] <= 1'b0; // One-shot stop
                    end else begin
                        timer_value <= timer_value - 1'b1;
                    end
                end else begin
                    prescale_counter <= prescale_counter + 1'b1;
                end
            end
        end
    end

    // APB Read / Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_ctrl     <= 32'd0;
            timer_prescale <= 32'd0;
            timer_load     <= 32'd0;
            pwm_cmp        <= 8'd0;
            prdata         <= 32'd0;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr)
                    `TIMER_REG_CTRL:     timer_ctrl     <= pwdata;
                    `TIMER_REG_PRESCALE: timer_prescale <= pwdata;
                    `TIMER_REG_LOAD: begin
                        timer_load  <= pwdata;
                        timer_value <= pwdata;
                    end
                    `TIMER_REG_PWM_CMP:  pwm_cmp <= pwdata[7:0];
                    default: ;
                endcase
            end

            if (psel && !pwrite) begin
                case (paddr)
                    `TIMER_REG_CTRL:     prdata <= timer_ctrl;
                    `TIMER_REG_PRESCALE: prdata <= timer_prescale;
                    `TIMER_REG_LOAD:     prdata <= timer_load;
                    `TIMER_REG_VALUE:    prdata <= timer_value;
                    default:             prdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
