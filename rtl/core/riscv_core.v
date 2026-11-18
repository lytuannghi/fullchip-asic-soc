// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    riscv_core.v
// Description: 5-Stage Pipelined RV32I Processor Core with Hazard & Forwarding
// =============================================================================

`timescale 1ns / 1ps

module riscv_core (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Memory Bus
    output wire [31:0] instr_addr,
    input  wire [31:0] instr_rdata,

    // Data Memory / APB Interconnect Bus
    output wire [31:0] data_addr,
    output wire [31:0] data_wdata,
    output wire [3:0]  data_wstrb,
    output wire        data_req,
    output wire        data_we,
    input  wire [31:0] data_rdata,
    input  wire        data_ready,

    // External Interrupt Input
    input  wire        ext_irq
);

    // -------------------------------------------------------------------------
    // IF Stage (Instruction Fetch)
    // -------------------------------------------------------------------------
    reg  [31:0] pc_f;
    wire [31:0] pc_next_f;
    wire [31:0] pc_plus4_f = pc_f + 32'd4;
    wire        stall_f, stall_d, flush_e, flush_d;
    wire        branch_taken_e;
    wire [31:0] branch_target_e;

    assign pc_next_f  = branch_taken_e ? branch_target_e : pc_plus4_f;
    assign instr_addr = pc_f;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_f <= 32'h0000_0000;
        end else if (!stall_f) begin
            pc_f <= pc_next_f;
        end
    end

    // -------------------------------------------------------------------------
    // ID Stage (Instruction Decode)
    // -------------------------------------------------------------------------
    reg  [31:0] instr_d, pc_d, pc_plus4_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_d    <= 32'h0000_0013; // NOP (addi x0, x0, 0)
            pc_d       <= 32'd0;
            pc_plus4_d <= 32'd0;
        end else if (flush_d) begin
            instr_d    <= 32'h0000_0013;
            pc_d       <= 32'd0;
            pc_plus4_d <= 32'd0;
        end else if (!stall_d) begin
            instr_d    <= instr_rdata;
            pc_d       <= pc_f;
            pc_plus4_d <= pc_plus4_f;
        end
    end

    // Instruction decoding
    wire [6:0] opcode = instr_d[6:0];
    wire [2:0] funct3 = instr_d[14:12];
    wire [6:0] funct7 = instr_d[31:25];
    wire [4:0] rs1_d  = instr_d[19:15];
    wire [4:0] rs2_d  = instr_d[24:20];
    wire [4:0] rd_d   = instr_d[11:7];

    // Immediate generation
    reg [31:0] imm_d;
    always @(*) begin
        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111: // I-type (ALU imm, Load, JALR)
                imm_d = {{20{instr_d[31]}}, instr_d[31:20]};
            7'b0100011: // S-type (Store)
                imm_d = {{20{instr_d[31]}}, instr_d[31:25], instr_d[11:7]};
            7'b1100011: // B-type (Branch)
                imm_d = {{20{instr_d[31]}}, instr_d[7], instr_d[30:25], instr_d[11:8], 1'b0};
            7'b0110111, 7'b0010111: // U-type (LUI, AUIPC)
                imm_d = {instr_d[31:12], 12'd0};
            7'b1101111: // J-type (JAL)
                imm_d = {{12{instr_d[31]}}, instr_d[19:12], instr_d[20], instr_d[30:21], 1'b0};
            default: imm_d = 32'd0;
        endcase
    end

    // Control Signals Generation
    reg        reg_write_d, mem_write_d, mem_read_d, alu_src_d, branch_d, jump_d, lui_d;
    reg [3:0]  alu_ctrl_d;

    always @(*) begin
        reg_write_d = 1'b0;
        mem_write_d = 1'b0;
        mem_read_d  = 1'b0;
        alu_src_d   = 1'b0;
        branch_d    = 1'b0;
        jump_d      = 1'b0;
        lui_d       = 1'b0;
        alu_ctrl_d  = 4'b0000;

        case (opcode)
            7'b0110011: begin // R-type ALU
                reg_write_d = 1'b1;
                case (funct3)
                    3'b000: alu_ctrl_d = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB / ADD
                    3'b001: alu_ctrl_d = 4'b0111; // SLL
                    3'b010: alu_ctrl_d = 4'b0101; // SLT
                    3'b011: alu_ctrl_d = 4'b0110; // SLTU
                    3'b100: alu_ctrl_d = 4'b0100; // XOR
                    3'b101: alu_ctrl_d = (funct7[5]) ? 4'b1001 : 4'b1000; // SRA / SRL
                    3'b110: alu_ctrl_d = 4'b0011; // OR
                    3'b111: alu_ctrl_d = 4'b0010; // AND
                endcase
            end

            7'b0010011: begin // I-type ALU
                reg_write_d = 1'b1;
                alu_src_d   = 1'b1;
                case (funct3)
                    3'b000: alu_ctrl_d = 4'b0000; // ADDI
                    3'b001: alu_ctrl_d = 4'b0111; // SLLI
                    3'b010: alu_ctrl_d = 4'b0101; // SLTI
                    3'b011: alu_ctrl_d = 4'b0110; // SLTIU
                    3'b100: alu_ctrl_d = 4'b0100; // XORI
                    3'b101: alu_ctrl_d = (funct7[5]) ? 4'b1001 : 4'b1000; // SRAI / SRLI
                    3'b110: alu_ctrl_d = 4'b0011; // ORI
                    3'b111: alu_ctrl_d = 4'b0010; // ANDI
                endcase
            end

            7'b0000011: begin // Load (LW)
                reg_write_d = 1'b1;
                alu_src_d   = 1'b1;
                mem_read_d  = 1'b1;
                alu_ctrl_d  = 4'b0000;
            end

            7'b0100011: begin // Store (SW)
                mem_write_d = 1'b1;
                alu_src_d   = 1'b1;
                alu_ctrl_d  = 4'b0000;
            end

            7'b1100011: begin // Branch (BEQ, BNE, BLT, BGE)
                branch_d   = 1'b1;
                alu_ctrl_d = 4'b0001; // Compare via SUB
            end

            7'b1101111: begin // JAL
                reg_write_d = 1'b1;
                jump_d      = 1'b1;
            end

            7'b0110111: begin // LUI
                reg_write_d = 1'b1;
                lui_d       = 1'b1;
            end

            default: ;
        endcase
    end

    // Register file instantiation
    wire [31:0] rdata1_d, rdata2_d;
    wire [4:0]  rd_w;
    wire [31:0] result_w;
    wire        reg_write_w;

    regfile u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (reg_write_w),
        .raddr1 (rs1_d),
        .raddr2 (rs2_d),
        .waddr  (rd_w),
        .wdata  (result_w),
        .rdata1 (rdata1_d),
        .rdata2 (rdata2_d)
    );

    // -------------------------------------------------------------------------
    // EX Stage (Execute)
    // -------------------------------------------------------------------------
    reg [31:0] rdata1_e, rdata2_e, imm_e, pc_e, pc_plus4_e;
    reg [4:0]  rs1_e, rs2_e, rd_e;
    reg [3:0]  alu_ctrl_e;
    reg [2:0]  funct3_e;
    reg        reg_write_e, mem_write_e, mem_read_e, alu_src_e, branch_e, jump_e, lui_e;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_e) begin
            rdata1_e    <= 32'd0;
            rdata2_e    <= 32'd0;
            imm_e       <= 32'd0;
            pc_e        <= 32'd0;
            pc_plus4_e  <= 32'd0;
            rs1_e       <= 5'd0;
            rs2_e       <= 5'd0;
            rd_e        <= 5'd0;
            alu_ctrl_e  <= 4'd0;
            funct3_e    <= 3'd0;
            reg_write_e <= 1'b0;
            mem_write_e <= 1'b0;
            mem_read_e  <= 1'b0;
            alu_src_e   <= 1'b0;
            branch_e    <= 1'b0;
            jump_e      <= 1'b0;
            lui_e       <= 1'b0;
        end else begin
            rdata1_e    <= rdata1_d;
            rdata2_e    <= rdata2_d;
            imm_e       <= imm_d;
            pc_e        <= pc_d;
            pc_plus4_e  <= pc_plus4_d;
            rs1_e       <= rs1_d;
            rs2_e       <= rs2_d;
            rd_e        <= rd_d;
            alu_ctrl_e  <= alu_ctrl_d;
            funct3_e    <= funct3;
            reg_write_e <= reg_write_d;
            mem_write_e <= mem_write_d;
            mem_read_e  <= mem_read_d;
            alu_src_e   <= alu_src_d;
            branch_e    <= branch_d;
            jump_e      <= jump_d;
            lui_e       <= lui_d;
        end
    end

    // Forwarding Multiplexers
    wire [1:0]  forward_a_e, forward_b_e;
    reg  [31:0] src_a_e, src_b_forwarded_e;
    wire [4:0]  rd_m;
    wire [31:0] alu_result_m;
    wire        reg_write_m;

    always @(*) begin
        case (forward_a_e)
            2'b10: src_a_e = alu_result_m;
            2'b01: src_a_e = result_w;
            default: src_a_e = rdata1_e;
        endcase

        case (forward_b_e)
            2'b10: src_b_forwarded_e = alu_result_m;
            2'b01: src_b_forwarded_e = result_w;
            default: src_b_forwarded_e = rdata2_e;
        endcase
    end

    wire [31:0] src_b_e = (alu_src_e) ? imm_e : src_b_forwarded_e;
    wire [31:0] alu_result_e;
    wire        zero_e;

    alu u_alu (
        .a        (src_a_e),
        .b        (src_b_e),
        .alu_ctrl (alu_ctrl_e),
        .result   (alu_result_e),
        .zero     (zero_e)
    );

    // Branch condition logic
    reg branch_cond_met;
    always @(*) begin
        case (funct3_e)
            3'b000: branch_cond_met = zero_e;                         // BEQ
            3'b001: branch_cond_met = !zero_e;                        // BNE
            3'b100: branch_cond_met = ($signed(src_a_e) < $signed(src_b_forwarded_e));  // BLT
            3'b101: branch_cond_met = ($signed(src_a_e) >= $signed(src_b_forwarded_e)); // BGE
            default: branch_cond_met = 1'b0;
        endcase
    end

    assign branch_taken_e  = (branch_e && branch_cond_met) || jump_e;
    assign branch_target_e = pc_e + imm_e;

    // Final result selection in EX (handle LUI, JAL, ALU)
    wire [31:0] ex_result_e = (lui_e)  ? imm_e :
                              (jump_e) ? pc_plus4_e : alu_result_e;

    // -------------------------------------------------------------------------
    // MEM Stage (Memory Access)
    // -------------------------------------------------------------------------
    reg [31:0] alu_result_m_reg, wdata_m, pc_plus4_m;
    reg [4:0]  rd_m_reg;
    reg        reg_write_m_reg, mem_write_m, mem_read_m;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_m_reg <= 32'd0;
            wdata_m          <= 32'd0;
            pc_plus4_m       <= 32'd0;
            rd_m_reg         <= 5'd0;
            reg_write_m_reg  <= 1'b0;
            mem_write_m      <= 1'b0;
            mem_read_m       <= 1'b0;
        end else begin
            alu_result_m_reg <= ex_result_e;
            wdata_m          <= src_b_forwarded_e;
            pc_plus4_m       <= pc_plus4_e;
            rd_m_reg         <= rd_e;
            reg_write_m_reg  <= reg_write_e;
            mem_write_m      <= mem_write_e;
            mem_read_m       <= mem_read_e;
        end
    end

    assign rd_m         = rd_m_reg;
    assign alu_result_m = alu_result_m_reg;
    assign reg_write_m  = reg_write_m_reg;

    // Memory Bus outputs
    assign data_addr  = alu_result_m_reg;
    assign data_wdata = wdata_m;
    assign data_wstrb = 4'b1111;
    assign data_req   = mem_read_m || mem_write_m;
    assign data_we    = mem_write_m;

    // -------------------------------------------------------------------------
    // WB Stage (Writeback)
    // -------------------------------------------------------------------------
    reg [31:0] alu_result_w, rdata_w;
    reg [4:0]  rd_w_reg;
    reg        reg_write_w_reg, mem_read_w;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_w    <= 32'd0;
            rdata_w         <= 32'd0;
            rd_w_reg        <= 5'd0;
            reg_write_w_reg <= 1'b0;
            mem_read_w      <= 1'b0;
        end else begin
            alu_result_w    <= alu_result_m_reg;
            rdata_w         <= data_rdata;
            rd_w_reg        <= rd_m;
            reg_write_w_reg <= reg_write_m;
            mem_read_w      <= mem_read_m;
        end
    end

    assign rd_w        = rd_w_reg;
    assign reg_write_w = reg_write_w_reg;
    assign result_w    = (mem_read_w) ? rdata_w : alu_result_w;

    // Hazard Unit
    hazard_unit u_hazard (
        .rs1_e          (rs1_e),
        .rs2_e          (rs2_e),
        .rd_m           (rd_m),
        .reg_write_m    (reg_write_m),
        .rd_w           (rd_w),
        .reg_write_w    (reg_write_w),
        .rs1_d          (rs1_d),
        .rs2_d          (rs2_d),
        .rd_e           (rd_e),
        .mem_read_e     (mem_read_e),
        .branch_taken_e (branch_taken_e),
        .forward_a_e    (forward_a_e),
        .forward_b_e    (forward_b_e),
        .stall_f        (stall_f),
        .stall_d        (stall_d),
        .flush_e        (flush_e),
        .flush_d        (flush_d)
    );

endmodule
