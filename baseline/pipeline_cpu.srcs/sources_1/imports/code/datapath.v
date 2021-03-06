`define WORD_SIZE 16
`include "ALU.v"

/*
 * datapath module connects registers or wires.
 * I implemented this as a schematic in the Lab06 PDF
 * and only WWD, HALT, JAL and JRL instruction need additional control signal.
 * Forwarding data to ID stage because WWD and other JMP instructions using
 * reg value in ID stage
 */

module datapath (
    input clk,
    input reset_n,
	
	output i_readM,
	output i_writeM,
	output [`WORD_SIZE-1:0] i_address,
	input [`WORD_SIZE-1:0] i_data,

	output d_readM,
	output d_writeM,
	output [`WORD_SIZE-1:0] d_address,
	inout [`WORD_SIZE-1:0] d_data,

    output [`WORD_SIZE-1:0] num_inst, 
    output [`WORD_SIZE-1:0] output_port, 
    output is_halted,

    input MemRead,
    input MemWrite,

    input [1:0] RegDst,
    input Jump,
    input Jump_R,
    input Branch,
    input MemtoReg,
    input [3:0] ALUOp,
    input ALUSrc1,
    input ALUSrc2,
    input RegWrite,
    
    input isWWD,
    input isHalt,

    output stall_out,
    
    output [3:0] opcode,
    output [5:0] func_code
);
    // internel register for PC and instruction
    reg [`WORD_SIZE-1:0] PC;
    wire [`WORD_SIZE-1:0] PC_jmp;
    reg [`WORD_SIZE-1:0] inst;
    reg [`WORD_SIZE-1:0] PC_next;
    // end of register //
    
    // Redef of in or out
    reg [`WORD_SIZE-1:0] num_inst;
    reg [`WORD_SIZE-1:0] output_port;
    ///////////////////////////

    // variables for wiring
    wire [`WORD_SIZE-1:0] data1, data2, data3;
    wire [1:0] addr1, addr2;
    wire [1:0] addr3;
    wire [`WORD_SIZE-1:0] ALUSrc1_wire, ALUSrc2_wire;
    wire [`WORD_SIZE-1:0] ALUSrc1_MUX_wire, ALUSrc2_MUX_wire, extended;
    wire [`WORD_SIZE-1:0] ALU_wire;
    wire Zero;
    wire flush;
    // for hazard detecting
    wire Branch_taken;
    assign Branch_taken = Branch & Zero;
    wire stall;
    // for control unit to stop write signal
    assign stall_out = stall;
    wire [1:0] ForwardA;
    wire [1:0] ForwardB;
    // for WWD instruction
    wire [`WORD_SIZE-1:0] A_wire;
    wire [`WORD_SIZE-1:0] B_wire;
    // Fowarding in ID stage. and store it in A
    /* 
     * 3: forward from WB stage
     * 2: forward from MEM stage
     * 1: forward from EX stage
     * 0: don't forwarding
     */
    assign A_wire = (ForwardA == 3) ? reg_data :
                    (ForwardA == 2) ? (MemtoReg_reg[1] ? d_data : ALUOut) :
                    (ForwardA == 1) ? ALU_wire :
                                      data1;
    // Fowarding in ID stage, and store it in B
    assign B_wire = (ForwardB == 3) ? reg_data :
                    (ForwardB == 2) ? (MemtoReg_reg[1] ? d_data : ALUOut) :
                    (ForwardB == 1) ? ALU_wire :
                                      data2;
    // end of var //

    // registers (A, B, ALUOut and so on..)
    reg [`WORD_SIZE-1:0] ALUOut;
	reg [`WORD_SIZE-1:0] reg_data;
    reg [`WORD_SIZE-1:0] A;
    reg [`WORD_SIZE-1:0] B;
    reg [`WORD_SIZE-1:0] extended_reg;
    reg [`WORD_SIZE-1:0] PC_carrie_reg[1:0];
    // this is for forwarding module
    reg [1:0] rt_reg;
    reg [1:0] rd_reg;
    reg [1:0] rs_reg;
    //////////////////   
    reg [1:0] write_addr_EX;
    reg [1:0] write_addr_MEM;
    reg [1:0] write_addr_WB;
    reg [`WORD_SIZE-1:0] ALUOut_WB;
    // this is for WWD instruction
    reg [`WORD_SIZE-1:0] A_reg[1:0];
    reg [`WORD_SIZE-1:0] B_reg;
    // this is for SWD instruction. carrying data2
    reg [`WORD_SIZE-1:0] data2_reg[1:0];
    reg [3:0] opcode_EX;
    reg [5:0] func_code_EX;
    reg [`WORD_SIZE-1:0] data3_reg_WB;
    // end of reg //  

	// control registers(each stage)
	/*
	 * each signal has array..
	 * 0: EX stage
	 * 1: MEM stage
	 * 2: WB stage
	 * control signal will be carried until it is used
	 */
	reg MemRead_reg[1:0];
	reg MemWrite_reg[1:0];
	reg [1:0] RegDst_reg;
	// maybe jump will be used directly?
	reg Jump_reg;
	reg Branch_reg;
    reg Branch_taken_reg;
    reg Jump_R_reg;
	reg MemtoReg_reg[2:0];
	reg [3:0] ALUOp_reg;
	reg ALUSrc1_reg;
    reg ALUSrc2_reg;
	reg RegWrite_reg[3:0];
	reg isWWD_reg[2:0];
	reg isHalt_reg;
    reg [`WORD_SIZE-1:0] d_data_reg;
    reg [`WORD_SIZE-1:0] ALUOut_reg;
    reg [1:0] addr3_reg;
	// end of reg//

    /*
     * usually, I named reg variable in this way
     * 
     *     ~_wire: wire used for MUXing data. 
     *     ~_reg : register used for carrying value to next stage. 
     *     ~_EX or ~_MEM..: used for carrying value in that stage.
     */
    // register wiring
    always @ (posedge clk) begin

        ALUOut <= ALU_wire;
        ALUOut_WB <= ALUOut;
        A <= A_wire;
        B <= B_wire;
        B_reg <= B;
        extended_reg <= extended;
        if (stall) begin
        PC_carrie_reg[0] <= PC_carrie_reg[0];
        PC_carrie_reg[1] <= PC_carrie_reg[1];
        end else begin
        PC_carrie_reg[0] <= PC + 1;
        PC_carrie_reg[1] <= PC_carrie_reg[0];
        end
        rt_reg <= inst[9:8];
        rd_reg <= inst[7:6];
        rs_reg <= inst[11:10];
        case (RegDst) 
            0 : write_addr_EX <= inst[9:8];
            1 : write_addr_EX <= inst[7:6];
            // this is for JAL or JRL instruction
            2 : write_addr_EX <= 2;
        endcase
        write_addr_MEM <= write_addr_EX;
        write_addr_WB <= write_addr_MEM;
        A_reg[0] <= A;
        A_reg[1] <= A;
        opcode_EX <= opcode;
        func_code_EX <= func_code;
        case (MemtoReg_reg[2])
            1: reg_data <= d_data_reg;
            0: reg_data <= ALUOut_reg;
        endcase
        Jump_R_reg <= Jump_R;
        Branch_taken_reg <= Branch_taken;
        Jump_reg <= Jump;
        d_data_reg <= d_data;
        ALUOut_reg <= ALUOut;
        addr3_reg <= addr3;

    end
    // end of wiring //

	// control carrier wiring
	always @ (posedge clk) begin
		MemRead_reg[0] <= MemRead;
		MemWrite_reg[0] <= MemWrite;
		MemRead_reg[1] <= MemRead_reg[0];
		MemWrite_reg[1] <= MemWrite_reg[0];
		RegDst_reg <= RegDst;
		Jump_reg <= Jump;
		Branch_reg <= Branch;
		MemtoReg_reg[0] <= MemtoReg;
		MemtoReg_reg[1] <= MemtoReg_reg[0];
		MemtoReg_reg[2] <= MemtoReg_reg[1];
		ALUOp_reg <= ALUOp;
        ALUSrc1_reg <= ALUSrc1;
		ALUSrc2_reg <= ALUSrc2;
        RegWrite_reg[0] <= RegWrite;
        RegWrite_reg[1] <= RegWrite_reg[0];
        RegWrite_reg[2] <= RegWrite_reg[1];
        RegWrite_reg[3] <= RegWrite_reg[2];
		isWWD_reg[0] <= isWWD;
        isWWD_reg[1] <= isWWD_reg[0];
        isWWD_reg[2] <= isWWD_reg[1];
		isHalt_reg <= isHalt;
	end
	// end of wiring

    assign is_halted = isHalt_reg;

    // read instruction data from memory Address 
	assign i_address = PC;
	assign i_readM = 1;
	assign i_writeM = 0;
    ///////////////////////

    // send data
    assign d_data = MemWrite_reg[1] ? B_reg : 16'bz;
    /////////////////////

    // load data
    assign d_address = ALUOut;

    // initializing cpu
    initial begin
        inst <= 0;
        PC <= 0;
        num_inst <= -2;
        reg_data <= 0;
    end
    //////////////////////

    // memory signal  
    assign d_readM = MemRead_reg[1];
    assign d_writeM = MemWrite_reg[1];
    //////////////////////

    // PC, inst update
    always @ (posedge clk) begin 
        if (reset_n == 0) begin
            PC <= 0;
            num_inst <= -2;
            inst <= 0;
        end
        else begin
            // stalling until data complete
            if (stall) begin
                PC <= PC;
                inst <= inst;
            end 
            // normal instruction
            else begin
            PC <= PC_next;
            // flushing
            if (flush) inst <= 0;
            else inst <= i_data;
            end
        end
    end
    always @ (inst) begin
        if (inst == 0) num_inst = num_inst;
        else num_inst = num_inst + 1;
    end
    // PC MUX
    // Jump: jump to PC jump
    // Jump_R: jump to regster #2 value
    // Branch: jump to PC + 1 + extended_reg
    always @ (Jump or Jump_R or PC_jmp or Branch_taken or PC_carrie_reg[0] or extended_reg or PC or A_wire) begin
        if (Jump) begin
            PC_next = PC_jmp;
        end
        else if (Jump_R) begin
            PC_next = A_wire;
        end
        else if (Branch_taken) begin
            PC_next = PC_carrie_reg[1] + extended;
        end
        else begin
            PC_next = PC + 1;
        end
    end
    /////////////////////////

    // PC_jmp wiring
    assign PC_jmp = {PC_carrie_reg[1][15:12], inst[11:0]};
    ///////////////////

    // output port
    // this implementation write output_port in WB stage
    // always @ (posedge clk) output_port = isWWD_reg[2] ? ALUOut_WB : output_port;
    ///////////////////////////////////////////////////////
    
    // this implementation write output_port in ID stage
    // So, when stall, output_port must stall...
    always @ (posedge clk) output_port = stall ? output_port : (isWWD ? A_wire : output_port);
    ////////////////////

    // instruction decoding
    assign opcode = inst[`WORD_SIZE-1:`WORD_SIZE-4];
    assign func_code = inst[5:0];
    ////////////////////////

    // wiring all mux or inputs
    assign addr1 = inst[11:10];
    assign addr2 = inst[9:8];
    assign addr3 = write_addr_WB;
    // in JAL, JRL instruction, have to save PC + 1 val to #2 reg
    assign ALUSrc1_wire = ALUSrc1_reg ? PC_carrie_reg[1] : A;
    // for I-type instruction
    assign ALUSrc2_wire = ALUSrc2_reg ? extended_reg : B;
    assign data3 = reg_data;
    //////////////////////

    // Register file wiring
    RegisterFile rf(
        .addr1(addr1), 
        .addr2(addr2), 
        .addr3(addr3_reg), 
        .data3(data3), 
        .write(RegWrite_reg[3]), 
        .clk(clk), 
        .reset_n(reset_n), 
        .data1(data1), 
        .data2(data2)
    );

    // ALU wiring
    ALU alu(
        .A(ALUSrc1_wire),
        .B(ALUSrc2_wire),
        .OP(ALUOp_reg),
        .C(ALU_wire)
    );

    comparator CP(
        .A(A_wire),
        .B(B_wire),
        .OP(ALUOp),

        .Zero(Zero)
    );

    hazard_detector hd(
        .Jump(Jump),
        .Jump_R(Jump_R),
        .Branch_taken(Branch_taken),

        .Jump_reg(Jump_reg),
        .Branch_taken_reg(Branch_taken_reg),
        .Jump_R_reg(Jump_R_reg),

        .flush(flush)
    );

    // stall_unit SU(
    //     .opcode(opcode),
    //     .func_code(func_code),
        
    //     .dest_EX(write_addr_EX),
    //     .dest_MEM(write_addr_MEM),
    //     .dest_WB(write_addr_WB),

    //     .RegWrite_reg_EX(RegWrite_reg[0]),
    //     .RegWrite_reg_MEM(RegWrite_reg[1]),
    //     .RegWrite_reg_WB(RegWrite_reg[2]),

    //     .rs_addr(inst[11:10]),
    //     .rt_addr(inst[9:8]),

    //     .stall(stall)
    // );

    forwarding_unit FU(
        .opcode(opcode),
        .func_code(func_code),

        .rs_addr(inst[11:10]),
        .rt_addr(inst[9:8]),

        .dest_EX(write_addr_EX),
        .dest_MEM(write_addr_MEM),
        .dest_WB(write_addr_WB),
        
        .RegWrite_reg_EX(RegWrite_reg[0]),
        .RegWrite_reg_MEM(RegWrite_reg[1]),
        .RegWrite_reg_WB(RegWrite_reg[2]),

        .MemRead_reg_EX(MemRead_reg[0]),
        .MemRead_reg_MEM(MemRead_reg[1]),

        .stall(stall),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB)
    );

    // sign extension module for ADI
    sign_extension SE(.imm(inst[7:0]), .extended(extended));

endmodule

module sign_extension(
    input [7:0] imm,
    output [`WORD_SIZE-1:0] extended
);
    assign extended = imm[7] ? { {8{1'b1}}, imm} : {8'b0, imm}; 
endmodule

// this module used for Branch instruction can Jump at ID stage
module comparator(
    input [`WORD_SIZE-1:0] A,
    input [`WORD_SIZE-1:0] B,

    input [3:0] OP,

    output reg Zero

);  
    always @ (*) begin
        case (OP)
            `OP_BNE : begin
                Zero = (A != B);
            end

            `OP_BEQ : begin
                Zero = (A == B);
            end

            `OP_BGZ : begin 
                if (A != 0) Zero = ~A[15];
                else Zero = 0;
            end

            `OP_BLZ : begin
                Zero = A[15];
            end
        endcase
    end
endmodule
 ////// end of def //////
 