#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kernels_api.h"
#include <audio.hpp>

// Compiler arguments (passed through audio_pipeline.mk):
// NUM_BLOCKS: Number of audio blocks (16)
// BLOCK_SIZE: Number of samples in each audio (1024)
// SAMPLERATE: Unused
// NORDER: Order of audio decoding (3)
// NUM_SRCS: Number of sources, or channel of audio (16)
// COH_MODE: Specialization of ESP/SPX coherence protocol (0)
// IS_ESP: Use ESP caches or Spandex caches (1)
// DO_CHAIN_OFFLOAD: Offload FFT-FIR-IFFT chain to accelerators, with regular invocation (0)
// DO_NP_CHAIN_OFFLOAD: Offload FFT-FIR-IFFT chain to accelerators, with SM invocation (0)
// USE_INT: Use int type for all data, or float for CPU data and fixed point for accelerators (1)
uint64_t start_init_rad;
uint64_t stop_init_rad;
uint64_t intvl_init_rad;
uint64_t start_init_vit;
uint64_t stop_init_vit;
uint64_t intvl_init_vit;
uint64_t start_prog;
uint64_t stop_prog;
uint64_t intvl_prog;
uint64_t start_iter_cv;
uint64_t stop_iter_cv;
uint64_t intvl_iter_cv;
uint64_t start_iter_rad;
uint64_t stop_iter_rad;
uint64_t intvl_iter_rad;
uint64_t start_iter_vit;
uint64_t stop_iter_vit;
uint64_t intvl_iter_vit;
uint64_t start_exec_cv;
uint64_t stop_exec_cv;
uint64_t intvl_exec_cv;
uint64_t start_exec_rad;
uint64_t stop_exec_rad;
uint64_t intvl_exec_rad;
uint64_t start_exec_vit;
uint64_t stop_exec_vit;
uint64_t intvl_exec_vit;

extern uint64_t calc_start;
extern uint64_t calc_stop;
extern uint64_t calc_intvl;
extern uint64_t fft_br_stop;
extern uint64_t fft_br_intvl;
extern uint64_t fft_cvtin_start;
extern uint64_t fft_cvtin_stop;
extern uint64_t fft_cvtin_intvl;
extern uint64_t fft_start;
extern uint64_t fft_stop;
extern uint64_t fft_intvl;
extern uint64_t fft_cvtout_start;
extern uint64_t fft_cvtout_stop;
extern uint64_t fft_cvtout_intvl;
extern uint64_t fft_start;
extern uint64_t fft_stop;
extern uint64_t fft_intvl;
extern uint64_t cdfmcw_start;
extern uint64_t cdfmcw_stop;
extern uint64_t cdfmcw_intvl;

extern uint64_t depunc_start;
extern uint64_t depunc_stop;
extern uint64_t depunc_intvl;
extern uint64_t dodec_start;
extern uint64_t dodec_stop;
extern uint64_t dodec_intvl;
extern uint64_t init_vit_buffer_start;
extern uint64_t init_vit_buffer_stop;
extern uint64_t init_vit_buffer_intvl;
extern uint64_t copy_vit_buffer_start;
extern uint64_t copy_vit_buffer_stop;
extern uint64_t copy_vit_buffer_intvl;
extern uint64_t descram_start;
extern uint64_t descram_stop;
extern uint64_t descram_intvl;

extern uint64_t bitrev_start;
extern uint64_t bitrev_stop;
extern uint64_t bitrev_intvl;

extern unsigned use_device_number;

bool_t all_obstacle_lanes_mode = BOOL_FALSE;

unsigned time_step = 0;         // The number of elapsed time steps
unsigned max_time_steps = 5000; // The max time steps to simulate (default to 5000)

struct esp_device *espdevs;
struct esp_device *fft_dev, *vit_dev;
struct esp_device *fft_sense_dev, *vit_sense_dev;
int ndev;

int num_vit_msgs = 1;   // the number of messages to send this time step (1 is default) 

volatile uint64_t* checkpoint = (volatile uint64_t*) 0xA8001000;

message_t message;
vehicle_state_t vehicle_state;

void PrintHeader();

int main(int argc, char **argv) {
    // read hart ID
 	uint64_t hartid = read_hartid();
    
    // ask mini-era to run on core 0
    if (hartid == 0) {
/*Code for mini-era*/
        printf("entering mini-main\n");

        label_t label;
        distance_t distance;

        radar_dict_entry_t* rdentry_p;
        distance_t rdict_dist;
        vit_dict_entry_t* vdentry_p;

        int opt;

        uint64_t old_val;

        intvl_prog = 0;
        intvl_iter_rad = 0;
        intvl_iter_vit = 0;
        intvl_iter_cv = 0;
        intvl_exec_rad = 0;
        intvl_exec_vit = 0;
        intvl_exec_cv = 0;
        calc_intvl = 0;
        fft_br_intvl = 0;
        bitrev_intvl = 0;
        fft_cvtin_intvl = 0;
        fft_intvl = 0;
        fft_cvtout_intvl = 0;
        cdfmcw_intvl = 0;
        depunc_intvl = 0;
        dodec_intvl = 0;
        init_vit_buffer_start = 0;
        init_vit_buffer_stop = 0;
        init_vit_buffer_intvl = 0;
        copy_vit_buffer_start = 0;
        copy_vit_buffer_stop = 0;
        copy_vit_buffer_intvl = 0;
        descram_start = 0;
        descram_stop = 0;
        descram_intvl = 0;

        // replaces sim opt "-f 0"
        crit_fft_samples_set = 0;
        SIM_DEBUG(printf("Using Radar Dictionary samples set %u for the critical FFT tasks\n", crit_fft_samples_set));

        // replaces sim opt "-v 2"
        vit_msgs_size = 2;
        SIM_DEBUG(printf("Using viterbi message size %u = %s\n", vit_msgs_size, vit_msgs_size_str[vit_msgs_size]));

        SIM_DEBUG(printf("Using %u maximum time steps (simulation)\n", max_time_steps));
        //BM: Commenting
        //printf("Using viterbi messages per step behavior %u = %s\n", vit_msgs_per_step, vit_msgs_per_step_str[vit_msgs_per_step]);

        #ifdef TWO_CORE_SCHED
        if (hartid == 1) {
            old_val = amo_swap(checkpoint, 0xcafebeed);
            while(*checkpoint != 1);
            amo_add (checkpoint, 1);
        } else {
            while(*checkpoint != 0xcafebeed);
            old_val = amo_swap(checkpoint, 1);
        }
        while(*checkpoint != 2);
        #endif

        #ifdef HW_FFT
        // find the FFT device
        #ifdef TWO_CORE_SCHED
        if (hartid == 0)
        #endif
        {
            ndev = probe(&espdevs, VENDOR_SLD, SLD_FFT, FFT_DEV_NAME);
            if (ndev == 0) {
                printf("fft not found\n");
                return 0;
            }
            printf("found fft\n");
            fft_dev = &espdevs[0];

        #if (USE_FFT_SENSOR || USE_VIT_SENSOR)
            ndev = probe(&espdevs, VENDOR_SLD, SLD_SENSOR_DMA, SENSE_DEV_NAME);
            if (ndev == 0) {
                printf("sensor DMA not found\n");
                return 0;
            }

            fft_sense_dev = &espdevs[0];
            vit_sense_dev = &espdevs[1];
        #endif // (USE_FFT_SENSOR || USE_VIT_SENSOR)
        }
        #endif // if HW_FFT

        #ifdef TWO_CORE_SCHED
        amo_add (checkpoint, 1);
        while(*checkpoint != 4);
        #endif

        #ifdef HW_VIT
        // find the Viterbi device
        #ifdef TWO_CORE_SCHED
        if (hartid == 1)
        #endif
        {
            ndev = probe(&espdevs, VENDOR_SLD, SLD_VITDODEC, VIT_DEV_NAME);
            if (ndev == 0) {
                printf("vitdodec not found\n");
                return 0;
            }

            vit_dev = &espdevs[0];
        }
        #endif // if HW_VIT

        #ifdef TWO_CORE_SCHED
        amo_add (checkpoint, 1);
        while(*checkpoint != 6);
        #endif

        //BM: Runs sometimes do not reset timesteps unless in main()
        time_step = 0;   
        SIM_DEBUG(printf("Doing initialization tasks...\n"));

        // initialize radar kernel - set up buffer
        SIM_DEBUG(printf("Initializing the Radar kernel...\n"));
        #ifdef TWO_CORE_SCHED
        if (hartid == 0)
        #endif
        {
            start_init_rad = get_counter();

            if (!init_rad_kernel())
            {
            printf("Error: the radar kernel couldn't be initialized properly.\n");
            return 1;
            }

            stop_init_rad = get_counter();
            intvl_init_rad = stop_init_rad - start_init_rad;
            printf("Done initializing Radar\n");
        }

        #ifdef TWO_CORE_SCHED
        amo_add (checkpoint, 1);
        while(*checkpoint != 8);
        #endif

        // initialize viterbi kernel - set up buffer
        SIM_DEBUG(printf("Initializing the Viterbi kernel...\n"));
        #ifdef TWO_CORE_SCHED
        if (hartid == 1)
        #endif
        {
            start_init_vit = get_counter();

            if (!init_vit_kernel())
            {
            printf("Error: the Viterbi decoding kernel couldn't be initialized properly.\n");
            return 1;
            }

            stop_init_vit = get_counter();
            intvl_init_vit = stop_init_vit - start_init_vit;

            // esp_flush(ACC_COH_NONE);
        }

        #ifdef TWO_CORE_SCHED
        amo_add (checkpoint, 1);
        while(*checkpoint != 10);
        #endif

        /* We assume the vehicle starts in the following state:
        *  - Lane: center
        *  - Speed: 50 mph
        */
        vehicle_state.active  = BOOL_TRUE;
        vehicle_state.lane    = center;
        vehicle_state.speed   = 50;
        SIM_DEBUG(printf("Vehicle starts with the following state: active: %u lane %u speed %d\n", vehicle_state.active, vehicle_state.lane, (int) vehicle_state.speed));

        printf("Starting the main loop...\n");

        #ifdef TWO_CORE_SCHED
        amo_add (checkpoint, 1);
        while(*checkpoint != 12);
        #endif

        // hardcoded for 'ITERATIONS' trace samples
        for (int i = 0; i < ITERATIONS; i++)
        {
            #ifdef TWO_CORE_SCHED
            if (hartid == 0)
            #endif
            {
            if (!read_next_trace_record(vehicle_state))
            {
                break;
            }
            }
            #ifdef TWO_CORE_SCHED
            else
            #endif
            {
            start_prog = get_counter();
            }

            //amo_add (checkpoint, 1);
            //while(*checkpoint != (14+4*i));
            
            // printf("  fffff\n");

            MIN_DEBUG(printf("Vehicle_State: Lane %u %s Speed %d\n", vehicle_state.lane, lane_names[vehicle_state.lane], (int) vehicle_state.speed));

            /* The radar kernel performs distance estimation on the next radar
            * data, and returns the estimated distance to the object.
            */
            #ifdef TWO_CORE_SCHED
            if (hartid == 0)
            #endif
            {
            start_iter_rad = get_counter();
            rdentry_p = iterate_rad_kernel(vehicle_state);
            stop_iter_rad = get_counter();
            if (time_step > 1) intvl_iter_rad += stop_iter_rad - start_iter_rad;

            rdict_dist = rdentry_p->distance;
            }

            /* The Viterbi decoding kernel performs Viterbi decoding on the next
            * OFDM symbol (message), and returns the extracted message.
            * This message can come from another car (including, for example,
            * its 'pose') or from the infrastructure (like speed violation or
            * road construction warnings). For simplicity, we define a fix set
            * of message classes (e.g. car on the right, car on the left, etc.)
            */
            #ifdef TWO_CORE_SCHED
            if (hartid == 1)
            #endif
            {
            // printf("  hhhhh\n");
            start_iter_vit = get_counter();
            vdentry_p = iterate_vit_kernel(vehicle_state);
            stop_iter_vit = get_counter();
            if (time_step > 1) intvl_iter_vit += stop_iter_vit - start_iter_vit;
            // printf("  iiiii\n");
            }

            #ifdef TWO_CORE_SCHED
            if (hartid == 0)
            #endif
            {
            start_exec_rad = get_counter();
            //BM: added print
            MIN_DEBUG(printf("\nInvoking execute_rad_kernel...\n"));
            distance = execute_rad_kernel(rdentry_p->return_data);
            //BM: added print
            MIN_DEBUG(printf("\nBack from execute_rad_kernel... distance = %d\n", (int) distance));
            stop_exec_rad = get_counter();
            intvl_exec_rad += stop_exec_rad - start_exec_rad;
            printf("Done Radar kernel\n");
            }

            #ifdef TWO_CORE_SCHED
            if (hartid == 1)
            #endif
            {
            // printf("  jjjjj\n");
            start_exec_vit = get_counter();
            //BM: added print
            MIN_DEBUG(printf("\nInvoking execute_vit_kernel...\n"));
            message = execute_vit_kernel(vdentry_p, num_vit_msgs);
            //BM: added print
            MIN_DEBUG(printf("\nBack from execute_vit_kernel... message = %d\n", message));
            stop_exec_vit = get_counter();
            intvl_exec_vit += stop_exec_vit - start_exec_vit;
            // printf("  kkkkk\n");
            }

            // POST-EXECUTE each kernels to gather stats, etc.
            #ifdef TWO_CORE_SCHED
            if (hartid == 0)
            #endif
            {
            post_execute_rad_kernel(rdentry_p->set, rdentry_p->index_in_set, rdict_dist, distance);
            // printf("  ddddd\n");
            }

            #ifdef TWO_CORE_SCHED
            if (hartid == 1)
            #endif
            {
            for (int mi = 0; mi < num_vit_msgs; mi++) {
                post_execute_vit_kernel(static_cast<message_t>(vdentry_p->msg_id), message);
            }
            // printf("  eeeee\n");
            }

            // amo_add (checkpoint, 1);
            // while(*checkpoint != (16+4*i));

            // printf("  ggggg\n");

            /* The plan_and_control() function makes planning and control decisions
            * based on the currently perceived information. It returns the new
            * vehicle state.
            */
            #ifdef TWO_CORE_SCHED
            if (hartid == 1)
            #endif
            {
            MIN_DEBUG(printf("Time Step %3u : Calling Plan and Control with message %u and distance %d\n", time_step, message, (int) distance));
            vehicle_state = plan_and_control(label, distance, message, vehicle_state);
            MIN_DEBUG(printf("New vehicle state: lane %u speed %d\n", vehicle_state.lane, (int) vehicle_state.speed));

            stop_prog = get_counter();
            intvl_prog += stop_prog - start_prog;

            // printf("Time Step %3u : Message %u and distance %d\n", time_step, message, (int) distance);

            time_step++;
            }
        }

        #ifdef TWO_CORE_SCHED
        if (hartid == 0)
        #endif
        {
            /* All the trace/simulation-time has been completed -- Quitting... */
            printf("\nRun completed %u time steps\n", time_step);

            /* All the traces have been fully consumed. Quitting... */
            closeout_rad_kernel();
            closeout_vit_kernel();

            printf("  iterate_rad_kernel run time    %lu cycles\n", intvl_iter_rad/ITERATIONS);
            printf("  iterate_vit_kernel run time    %lu cycles\n", intvl_iter_vit/ITERATIONS);

            // These are timings taken from called routines...
            printf("\n");
            printf("  execute_rad_kernel run time    %lu cycles\n", intvl_exec_rad/ITERATIONS);
            printf("  fft_cvtin   run time    %lu cycles\n", fft_cvtin_intvl/ITERATIONS);
            printf("  fft-comp    run time    %lu cycles\n", fft_intvl/ITERATIONS);
            printf("  fft_cvtout  run time    %lu cycles\n", fft_cvtout_intvl/ITERATIONS);

            printf("\n");
            printf("  execute_vit_kernel run time    %lu cycles\n", intvl_exec_vit/ITERATIONS);
            printf("  do-decoding run time    %lu cycles\n", dodec_intvl/ITERATIONS);
            printf("  descram run time    %lu cycles\n", descram_intvl/ITERATIONS);

            printf("\nProgram total execution time     %lu cycles\n", intvl_prog/ITERATIONS);

            printf("\nDone.\n");
        }
        while (1);
    }

    if (hartid == 1) {
/*Code for audio pipeline*/    
        PrintHeader();

        const int numBlocks = NUM_BLOCKS;

        ABAudio audio;
        // Configure all tasks in the pipeline,
        // and initialize any data.
        audio.Configure();

        audio.loadSource();

        // Process all audio blocks one by one.
        for (int i = 0; i < numBlocks; i++) {
            audio.processBlock();
            printf("Block %d done\n", i);
        }

        // Print out profile results.
        audio.PrintTimeInfo(numBlocks);

        while(1);
    }
    return 0;
}

void PrintHeader() {
    printf("--------------------------------------------------------------------------------------\n");
    printf("3D SPATIAL AUDIO DECODER: ");
    printf("%s\n", (DO_CHAIN_OFFLOAD ? ((USE_MONOLITHIC_ACC)? "Monolithic Accelerator for FFT-FIR-IFFT" :"Composed Fine-Grained Accelerators for FFT-FIR-IFFT") :
                                (DO_NP_CHAIN_OFFLOAD ? ((USE_MONOLITHIC_ACC)? "Monolithic Accelerator with ASI" :"Composed Fine-Grained Accelerators with ASI") :
                                (DO_PP_CHAIN_OFFLOAD ? ((USE_MONOLITHIC_ACC)? "Hardware Pipelining" : "Software Pipelining" ):
                                (DO_FFT_IFFT_OFFLOAD) ? "Hardware Acceleration of FFT-IFFT in EPOCHS" :
                                "All Software in EPOCHS"))));

    printf("--------------------------------------------------------------------------------------\n");
}
