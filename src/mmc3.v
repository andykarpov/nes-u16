// This mapper also handles mapper 119 and 47.
module MMC3(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                            // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
            output reg irq);
  reg [2:0] bank_select;             // Register to write to next
  reg prg_rom_bank_mode;             // Mode for PRG banking
  reg chr_a12_invert;                // Mode for CHR banking
  reg mirroring;                     // 0 = vertical, 1 = horizontal
  reg irq_enable, irq_reload;        // IRQ enabled, and IRQ reload requested
  reg [7:0] irq_latch, counter;      // IRQ latch value and current counter
  reg ram_enable, ram_protect;       // RAM protection bits
  reg [6:0] chr_bank_0, chr_bank_1;  // Selected CHR banks
  reg [7:0] chr_bank_2, chr_bank_3, chr_bank_4, chr_bank_5;
  reg [5:0] prg_bank_0, prg_bank_1;  // Selected PRG banks
  wire prg_is_ram;
    
  // The alternative behavior has slightly different IRQ counter semantics.
  wire mmc3_alt_behavior = 0;
  
  // TQROM maps 8kB CHR RAM
  wire TQROM = (flags[7:0] == 119);
  wire TxSROM = (flags[7:0] == 118); // Connects CHR A17 to CIRAM A10
  
  // Mapper 47 is a multicart that has 128k for each game. It has no RAM.
  wire mapper47 = (flags[7:0] == 47);
  reg mapper47_multicart;
    
  wire [7:0] new_counter = (counter == 0 || irq_reload) ? irq_latch : counter - 1;
  reg [3:0] a12_ctr; 
   
  always @(posedge clk) if (reset) begin
    irq <= 0;
    bank_select <= 0;
    prg_rom_bank_mode <= 0;
    chr_a12_invert <= 0;
    mirroring <= 0;
    {irq_enable, irq_reload} <= 0;
    {irq_latch, counter} <= 0;
    {ram_enable, ram_protect} <= 0;
    {chr_bank_0, chr_bank_1} <= 0;
    {chr_bank_2, chr_bank_3, chr_bank_4, chr_bank_5} <= 0;
    {prg_bank_0, prg_bank_1} <= 0;
    a12_ctr <= 0;
  end else if (ce) begin
    if (prg_write && prg_ain[15]) begin
      case({prg_ain[14], prg_ain[13], prg_ain[0]})
      3'b00_0: {chr_a12_invert, prg_rom_bank_mode, bank_select} <= {prg_din[7], prg_din[6], prg_din[2:0]}; // Bank select ($8000-$9FFE, even)
      3'b00_1: begin // Bank data ($8001-$9FFF, odd)
        case (bank_select) 
        0: chr_bank_0 <= prg_din[7:1];  // Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF);
        1: chr_bank_1 <= prg_din[7:1];  // Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF);
        2: chr_bank_2 <= prg_din;       // Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF);
        3: chr_bank_3 <= prg_din;       // Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF);
        4: chr_bank_4 <= prg_din;       // Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF);
        5: chr_bank_5 <= prg_din;       // Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF);
        6: prg_bank_0 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $8000-$9FFF (or $C000-$DFFF);
        7: prg_bank_1 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $A000-$BFFF
        endcase
      end
      3'b01_0: mirroring <= prg_din[0];                   // Mirroring ($A000-$BFFE, even)
      3'b01_1: {ram_enable, ram_protect} <= prg_din[7:6]; // PRG RAM protect ($A001-$BFFF, odd)
      3'b10_0: irq_latch <= prg_din;                      // IRQ latch ($C000-$DFFE, even)
      3'b10_1: irq_reload <= 1;                           // IRQ reload ($C001-$DFFF, odd)
      3'b11_0: begin irq_enable <= 0; irq <= 0; end       // IRQ disable ($E000-$FFFE, even)
      3'b11_1: irq_enable <= 1;                           // IRQ enable ($E001-$FFFF, odd)
      endcase
    end
    
    // For Mapper 47
    // $6000-7FFF:  [.... ...B]  Block select
    if (prg_write && prg_is_ram)
      mapper47_multicart <= prg_din[0];
        
    // Trigger IRQ counter on rising edge of chr_ain[12]
    // All MMC3A's and non-Sharp MMC3B's will generate only a single IRQ when $C000 is $00.
    // This is because this version of the MMC3 generates IRQs when the scanline counter is decremented to 0.
    // In addition, writing to $C001 with $C000 still at $00 will result in another single IRQ being generated.
    // In the community, this is known as the "alternate" or "old" behavior.
    // All MMC3C's and Sharp MMC3B's will generate an IRQ on each scanline while $C000 is $00.
    // This is because this version of the MMC3 generates IRQs when the scanline counter is equal to 0.
    // In the community, this is known as the "normal" or "new" behavior.
    if (chr_ain[12] && a12_ctr == 0) begin
      counter <= new_counter;
      if ( (!mmc3_alt_behavior  || counter != 0 || irq_reload) && new_counter == 0 && irq_enable) begin
//        $write("MMC3 SCANLINE IRQ!\n");
        irq <= 1;
      end
      irq_reload <= 0;      
    end
    a12_ctr <= chr_ain[12] ? 4'b1111 : (a12_ctr != 0) ? a12_ctr - 4'b0001 : a12_ctr;
  end

  // The PRG bank to load. Each increment here is 8kb. So valid values are 0..63.
  reg [5:0] prgsel;
  always @* begin
    casez({prg_ain[14:13], prg_rom_bank_mode})
    3'b00_0: prgsel = prg_bank_0;  // $8000 mode 0
    3'b00_1: prgsel = 6'b111110;   // $8000 fixed to second last bank
    3'b01_?: prgsel = prg_bank_1;  // $A000 mode 0,1
    3'b10_0: prgsel = 6'b111110;   // $C000 fixed to second last bank
    3'b10_1: prgsel = prg_bank_0;  // $C000 mode 1
    3'b11_?: prgsel = 6'b111111;   // $E000 fixed to last bank
    endcase
    // mapper47 is limited to 128k PRG, the top bits are controlled by mapper47_multicart instead.
    if (mapper47) prgsel[5:4] = {1'b0, mapper47_multicart};
  end

  // The CHR bank to load. Each increment here is 1kb. So valid values are 0..255.
  reg [7:0] chrsel;
  always @* begin
    casez({chr_ain[12] ^ chr_a12_invert, chr_ain[11], chr_ain[10]})
    3'b00?: chrsel = {chr_bank_0, chr_ain[10]};
    3'b01?: chrsel = {chr_bank_1, chr_ain[10]};
    3'b100: chrsel = chr_bank_2;
    3'b101: chrsel = chr_bank_3;
    3'b110: chrsel = chr_bank_4;
    3'b111: chrsel = chr_bank_5;
    endcase
    // mapper47 is limited to 128k CHR, the top bit is controlled by mapper47_multicart instead.
    if (mapper47) chrsel[7] = mapper47_multicart;
  end

  wire [21:0] prg_aout_tmp = {3'b00_0,  prgsel, prg_ain[12:0]};

  assign {chr_allow, chr_aout} = 
      (TQROM && chrsel[6]) ? {1'b1,      9'b11_1111_111, chrsel[2:0], chr_ain[9:0]} :   // TQROM 8kb CHR-RAM
                             {flags[15], 4'b10_00, chrsel, chr_ain[9:0]};               // Standard MMC3

  assign prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000 && ram_enable && !(ram_protect && prg_write);
  assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram && !mapper47;
  wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
  assign prg_aout = prg_is_ram  && !mapper47 ? prg_ram : prg_aout_tmp;
  assign vram_a10 = (TxSROM == 0) ? (mirroring ? chr_ain[11] : chr_ain[10]) :
                                    chrsel[7];
  assign vram_ce = chr_ain[13];
endmodule