module pmux(
	input wire [8:0] data_i,
	output reg [3:0] zero_cnt
);

always @(*) begin
        casez (data_i)
            9'b1????????: zero_cnt = 4'd0;
            9'b01???????: zero_cnt = 4'd1;
            9'b001??????: zero_cnt = 4'd2;
            9'b0001?????: zero_cnt = 4'd3;
            9'b00001????: zero_cnt = 4'd4;
            9'b000001???: zero_cnt = 4'd5;
            9'b0000001??: zero_cnt = 4'd6;
            9'b00000001?: zero_cnt = 4'd7;
            9'b000000001: zero_cnt = 4'd8;
            default:      zero_cnt = 4'd0;
        endcase
end

endmodule
